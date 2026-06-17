# 07 - Deteccion y monitorizacion

## Objetivo

Demostrar como herramientas de seguridad especializadas permiten detectar
vulnerabilidades en imagenes Docker (Trivy) y comportamientos sospechosos
en contenedores en tiempo real (Falco).

---

## Script utilizado

```bash
chmod +x scripts/detection.sh
./scripts/detection.sh
```

---

## Parte 1: Trivy — Escaneo de vulnerabilidades en imagenes

### ¿Que es Trivy?

Trivy es un escaner de vulnerabilidades open source desarrollado por
Aqua Security. Es la herramienta mas utilizada en entornos Docker y
Kubernetes para detectar problemas de seguridad antes de que lleguen
a produccion.

Cuando se le pasa una imagen Docker, Trivy la desmonta capa por capa
y analiza:

| Tipo de analisis | Que detecta | Ejemplo |
|---|---|---|
| CVEs | Vulnerabilidades conocidas en paquetes | `CVE-2023-46233 (CRITICAL)` |
| Secretos | Claves y tokens hardcodeados | `-----BEGIN RSA PRIVATE KEY-----` |
| Misconfigs | Configuraciones inseguras | `USER root` en Dockerfile |
| Licencias | Licencias problematicas | GPL en proyecto comercial |

### Severidades

| Nivel | Significado |
|---|---|
| CRITICAL | Explotable remotamente, sin autenticacion |
| HIGH | Explotable con condiciones especificas |
| MEDIUM | Requiere acceso previo para explotar |
| LOW | Impacto limitado |

### Instalacion

```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb generic main" | \
    tee /etc/apt/sources.list.d/trivy.list

apt update && apt install -y trivy
```

---

### Escaneo de Juice Shop

```bash
trivy image --severity HIGH,CRITICAL bkimminich/juice-shop
```

#### Resultado

```
Total: 44 (HIGH: 39, CRITICAL: 5)
```

44 vulnerabilidades encontradas, 5 de ellas CRITICAS.

#### CVEs mas graves

| CVE | Paquete | Severidad | Descripcion |
|---|---|---|---|
| CVE-2023-46233 | crypto-js | CRITICAL | PBKDF2 1000x mas debil de lo especificado |
| CVE-2015-9235 | jsonwebtoken | CRITICAL | Bypass de verificacion de tokens JWT |
| CVE-2019-10744 | lodash | CRITICAL | Prototype pollution en defaultsDeep |
| GHSA-5mrr-rgp6-x4gr | marsdb | CRITICAL | Command Injection directo |
| CVE-2020-15084 | express-jwt | HIGH | Authorization bypass |

#### Hallazgo especial: clave privada RSA hardcodeada

Ademas de los CVEs, Trivy encontro un secreto critico:

```
/juice-shop/lib/insecurity.ts (secrets)
Total: 1 (HIGH: 1)
HIGH: AsymmetricPrivateKey (private-key)
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

La clave privada RSA que usa Juice Shop para firmar los tokens JWT
esta hardcodeada en el codigo fuente. Cualquier persona con acceso
al repositorio o a la imagen puede extraerla y falsificar tokens JWT
para acceder como cualquier usuario sin necesitar contrasena.

Combinado con CVE-2015-9235 (bypass de verificacion JWT), esto
representa un compromiso total del sistema de autenticacion.

---

### Escaneo de ubuntu:22.04

```bash
trivy image ubuntu:22.04
```

#### Resultado

```
util-linux | CVE-2026-27456 | TOCTOU in the mount program
```

Solo 1 vulnerabilidad de baja severidad, relacionada con una condicion
de carrera en el programa `mount`.

### Comparativa de imagenes

| Imagen | CRITICAL | HIGH | Total | Conclusion |
|---|---|---|---|---|
| `bkimminich/juice-shop` | 5 | 39 | 44 | Dependencias Node.js muy desactualizadas |
| `ubuntu:22.04` | 0 | 0 | 1 (LOW/MED) | Imagen base bien mantenida |

### Conclusion de Trivy

La diferencia entre las dos imagenes demuestra un principio clave:

> El problema no es la imagen base sino las **dependencias de la
> aplicacion**. Ubuntu 22.04 esta bien mantenido y casi no tiene
> vulnerabilidades. Juice Shop acumula 44 vulnerabilidades porque
> usa librerias Node.js antiguas y sin actualizar.
>
> En produccion, Trivy deberia ejecutarse en cada build del pipeline
> CI/CD para detectar nuevas vulnerabilidades antes de desplegar.

---

## Parte 2: Falco — Deteccion en tiempo real

### ¿Que es Falco?

Falco es una herramienta de seguridad en tiempo de ejecucion (runtime
security) desarrollada por Sysdig y donada a la CNCF. Mientras Trivy
analiza imagenes estaticas, Falco monitoriza lo que ocurre mientras
los contenedores estan corriendo.

Falco usa **eBPF** (extended Berkeley Packet Filter) para interceptar
llamadas al sistema del kernel y compararlas con un conjunto de reglas.
Cuando detecta comportamiento sospechoso genera alertas en tiempo real.

Detecta cosas como:
- Alguien ejecutando una shell dentro de un contenedor
- Un proceso intentando leer `/etc/shadow`
- Un contenedor instalando software no previsto
- Un contenedor intentando montar el filesystem del host
- Cualquier binario que no formaba parte de la imagen original

### Instalacion

```bash
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc -o /tmp/falco.asc
/usr/bin/gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg /tmp/falco.asc

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
https://download.falco.org/packages/deb stable main" | \
    tee /etc/apt/sources.list.d/falcosecurity.list

apt update && apt install -y falco
```

Verificar que esta corriendo:

```bash
systemctl status falco-modern-bpf
# Active: active (running)
```

### Ver logs en tiempo real

```bash
journalctl -fu falco-modern-bpf
```

---

### Demostracion: Falco detectando el container escape

Se ejecuto el ataque completo con Falco monitorizando en tiempo real.
Estas son las alertas generadas en orden cronologico:

#### Alerta 1 — Entrada al contenedor vulnerable

```
03:16:11: Notice A shell was spawned in a container
user=root user_uid=0
container_name=vuln-container
container_image_tag=22.04
exe_flags=EXE_WRITABLE|EXE_LOWER_LAYER
```

Falco detecta que alguien abrio una shell interactiva dentro del
contenedor como root.

#### Alerta 2 — Instalacion de docker (apt install docker.io)

```
03:18:02: Critical Executing binary not part of base image
proc_exe=aa-enabled parent=dpkg
container_name=vuln-container
exe_flags=EXE_WRITABLE|EXE_UPPER_LAYER

03:18:02: Critical Executing binary not part of base image
proc_exe=openssl parent=update-ca-certi
container_name=vuln-container

03:18:06: Critical Executing binary not part of base image
proc_exe=getcap parent=iproute2.postin
container_name=vuln-container
```

Falco detecta cada binario nuevo instalado por apt como CRITICAL
porque no formaba parte de la imagen original ubuntu:22.04.

#### Alerta 3 — El container escape

```
03:19:45: Critical Executing binary not part of base image
proc_exe=bash parent=containerd-shim
command=docker run -it --rm -v /:/host alpine chroot /host bash
container_name=vuln-container
exe_flags=EXE_WRITABLE|EXE_UPPER_LAYER
```

**Falco detecto el comando exacto del container escape**, incluyendo
los flags `-v /:/host` que montan el filesystem del host.

#### Alerta 4 — Shell en el host (post-escape)

```
03:19:46: Notice A shell was spawned in a container
user=root user_uid=0
container_id=cfa4f45ed008
container_image_repository=<NA>
```

Falco detecta el nuevo contenedor alpine creado por el escape, sin
nombre de imagen (porque se creo dinamicamente).

---

### Comparativa: contenedor vulnerable vs hardenizado

| Accion | Contenedor vulnerable | Contenedor hardenizado |
|---|---|---|
| Entrada con bash | Notice: shell spawned (root) | Notice: shell spawned (uid=1000) |
| `cat /etc/shadow` | Permitido | Permission denied |
| `apt install` | Critical: binary not in base image | Error: read-only filesystem |
| Container escape | Critical: docker run detectado | bash: docker not found |

---

### Por que Falco no previene, sino detecta

Es importante entender el rol de Falco:

> Falco es una herramienta de **deteccion**, no de prevencion.
> No bloquea los ataques, los registra. Su valor esta en:
>
> 1. Generar alertas en tiempo real para que el equipo de seguridad
>    pueda responder inmediatamente.
> 2. Dejar un registro forense completo de cada accion sospechosa
>    con timestamps exactos.
> 3. Integrarse con sistemas SIEM, Slack, PagerDuty, etc. para
>    notificaciones automaticas.
>
> La prevencion viene del hardening (fase anterior). Falco es la
> capa de visibilidad que detecta cuando algo se escapa del hardening.

---

## Resumen de hallazgos de la fase de deteccion

| Herramienta | Hallazgo | Severidad |
|---|---|---|
| Trivy | 5 CVEs CRITICAL en Juice Shop | CRITICAL |
| Trivy | Clave privada RSA hardcodeada | HIGH |
| Trivy | 39 CVEs HIGH en Juice Shop | HIGH |
| Trivy | CVE-2026-27456 en ubuntu:22.04 | LOW/MEDIUM |
| Falco | Shell spawned como root en contenedor | Notice |
| Falco | Instalacion de binarios no previstos | CRITICAL |
| Falco | Comando de container escape detectado | CRITICAL |
| Falco | Nuevo contenedor creado sin imagen conocida | Notice |

---

## Conclusion

La combinacion de Trivy y Falco cubre dos dimensiones complementarias
de la seguridad en contenedores:

- **Trivy** actua antes del despliegue: detecta vulnerabilidades
  conocidas en las imagenes antes de que lleguen a produccion.

- **Falco** actua durante la ejecucion: detecta comportamientos
  anomalos en tiempo real aunque no haya una vulnerabilidad conocida.

Juntos forman una estrategia de seguridad en profundidad que sigue
el principio **"shift left"**: detectar problemas lo mas pronto posible
en el ciclo de vida del software, reduciendo el coste y el impacto
de los incidentes de seguridad.
