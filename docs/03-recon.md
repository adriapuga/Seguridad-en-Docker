# 03 - Reconocimiento desde Kali

## Objetivo

Identificar los servicios activos en el servidor victima, analizar su
configuracion y recopilar informacion util para la fase de explotacion.
Todo el reconocimiento se realiza desde la VM Kali Linux.

---

## Herramientas utilizadas

| Herramienta | Proposito |
|---|---|
| `ping` | Verificar conectividad con el objetivo |
| `nmap` | Descubrir puertos abiertos y versiones de servicios |
| `curl` | Analizar cabeceras HTTP |
| `whatweb` | Fingerprinting de tecnologias web |
| `gobuster` | Enumeracion de rutas y directorios |

---

## Script utilizado

El reconocimiento se automatizo con el script `recon.sh`:

```bash
chmod +x scripts/recon.sh
./scripts/recon.sh 192.168.122.95
```

El script ejecuta todas las fases en orden y guarda el resultado en:

```
reports/recon_192.168.122.95_<fecha>.txt
```

---

## Fase 1: Verificacion de conectividad

```bash
ping -c 3 192.168.122.95
```

Resultado: host activo, paquetes recibidos sin perdida.

---

## Fase 2: Escaneo de puertos con nmap

```bash
nmap -sV -p- --open 192.168.122.95
```

### Superficie de ataque descubierta

| Puerto | Estado | Servicio | Version | Vector de ataque |
|---|---|---|---|---|
| 22/tcp | Abierto | SSH | OpenSSH 9.2p1 (Debian 12) | Fuerza bruta con hydra |
| 80/tcp | Abierto | HTTP | Apache httpd 2.4.67 (Debian) | Enumeracion de rutas, CVEs |
| 3000/tcp | Abierto | HTTP | OWASP Juice Shop (Node.js) | OWASP Top 10 |

### Informacion adicional extraida

- **MAC Address**: `52:54:00:3D:07:E6` — prefijo QEMU/KVM, delata entorno virtualizado
- **OS detectado**: Linux (kernel confirmado por banner SSH)
- **Distribucion**: Debian 12 (deducido de `2+deb12u10` en el banner de OpenSSH)

---

## Fase 3: Analisis de cabeceras HTTP

```bash
curl -I http://192.168.122.95:3000
curl -I http://192.168.122.95:80
```

### Puerto 3000 — Juice Shop

| Cabecera | Valor | Hallazgo |
|---|---|---|
| `X-Recruiting` | `/#/jobs` | Information disclosure: ruta interna expuesta |
| `Access-Control-Allow-Origin` | `*` | CORS abierto a cualquier dominio |
| `Feature-Policy` | `payment 'self'` | Cabecera obsoleta, app desactualizada |
| `Strict-Transport-Security` | No presente | Sin forzado de HTTPS |
| `Content-Security-Policy` | No presente | Sin proteccion contra XSS |
| `Referrer-Policy` | No presente | Sin control de referrers |

### Puerto 80 — Apache

| Cabecera | Valor | Hallazgo |
|---|---|---|
| `Server` | `Apache/2.4.67 (Debian)` | Version exacta expuesta |
| `Content-Type` | `text/html` | Pagina por defecto sin configurar |

---

## Fase 4: Fingerprinting con whatweb

```bash
whatweb http://192.168.122.95:3000
whatweb http://192.168.122.95:80
```

### Resultados

**Puerto 3000:**
```
[200 OK] HTML5, IP[192.168.122.95], Script[module],
Title[OWASP Juice Shop],
UncommonHeaders[access-control-allow-origin,x-content-type-options,
feature-policy,x-recruiting], X-Frame-Options[SAMEORIGIN]
```

**Puerto 80:**
```
[200 OK] Apache[2.4.67], HTTPServer[Debian Linux][Apache/2.4.67 (Debian)],
IP[192.168.122.95], Title[Apache2 Debian Default Page: It works]
```

### Analisis

| Puerto | Tecnologia detectada | Relevancia |
|---|---|---|
| 3000 | Node.js + Angular (SPA) | Confirma Juice Shop sin autenticacion |
| 3000 | Headers no estandar (`x-recruiting`) | Information disclosure |
| 80 | Apache 2.4.67 sobre Debian | Version exacta → busqueda de CVEs |
| 80 | Pagina por defecto | Servicio sin configurar, posible vector |

---

## Fase 5: Enumeracion de rutas con gobuster

```bash
gobuster dir \
    -u http://192.168.122.95:3000 \
    -w /usr/share/wordlists/dirb/common.txt \
    -q --no-error --xl 9903

gobuster dir \
    -u http://192.168.122.95:80 \
    -w /usr/share/wordlists/dirb/common.txt \
    -q --no-error
```

### Resultados puerto 3000

| Ruta | Status | Significado |
|---|---|---|
| `/api` | 500 Internal Server Error | Endpoint API REST expuesto |
| `/apis` | 500 Internal Server Error | Endpoint API REST expuesto |
| `/assets` | 301 Redirect | Recursos estaticos (JS, CSS, imagenes) |

El error 500 en `/api` y `/apis` confirma que los endpoints existen y
procesan peticiones. Seran objetivos en la fase de explotacion.

Nota tecnica: Juice Shop es una SPA (Single Page Application) con Angular.
El servidor devuelve siempre el mismo `index.html` para rutas no existentes
(tamano 9903 bytes), por lo que se filtran esas respuestas con `--xl 9903`.

### Resultados puerto 80

| Ruta | Status | Significado |
|---|---|---|
| `.htaccess` | 403 Forbidden | Existe pero no accesible |
| `.htpasswd` | 403 Forbidden | Archivo de contrasenas protegido |
| `.hta` | 403 Forbidden | Existe pero bloqueado |
| `index.html` | 200 OK | Pagina por defecto de Apache |
| `server-status` | 403 Forbidden | Panel de estado de Apache bloqueado |

---

## Resumen de hallazgos

| # | Hallazgo | Riesgo | Fase donde se explota |
|---|---|---|---|
| 1 | SSH puerto 22 (OpenSSH 9.2p1) | Alto | Fase 4: fuerza bruta con hydra |
| 2 | Apache 2.4.67 con version expuesta | Medio | Busqueda de CVEs |
| 3 | Juice Shop accesible en puerto 3000 | Alto | Fase 4: SQLi, XSS, IDOR |
| 4 | Header `X-Recruiting` con ruta interna | Bajo | Information disclosure |
| 5 | CORS abierto (`*`) | Medio | Vector CSRF/robo de datos |
| 6 | Cabeceras de seguridad ausentes | Medio | XSS, clickjacking, MITM |
| 7 | Endpoints `/api` y `/apis` expuestos | Alto | Fase 4: explotacion de API |
| 8 | `.htpasswd` existe en Apache | Medio | Posible archivo de credenciales |

---

## Notas

> El reconocimiento es la fase mas importante de un ataque. Un atacante
> experimentado puede obtener informacion critica del objetivo sin interactuar
> directamente con el sistema. Solo con nmap, curl y whatweb ya conocemos:
> el sistema operativo, las versiones exactas de software, las tecnologias
> usadas, las rutas expuestas y la postura de seguridad del servidor.
> Todo esto sin haber "atacado" nada todavia.
