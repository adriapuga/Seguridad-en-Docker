# 06 - Hardening defensivo

## Objetivo

Aplicar medidas de seguridad al stack Docker para eliminar los vectores
de ataque demostrados en la fase ofensiva, y demostrar que el mismo
ataque ya no es viable.

---

## Script utilizado

```bash
chmod +x scripts/hardening.sh
./scripts/hardening.sh
```

---

## Fase 1: Parar el stack vulnerable

```bash
cd ~/docker-security-lab
docker compose down
```

Los contenedores vulnerables (`juiceshop` y `vuln-container`) se paran
antes de levantar el stack hardenizado.

---

## Fase 2: El nuevo stack hardenizado

### docker-compose.hardened.yml

```yaml
services:
  juiceshop:
    image: bkimminich/juice-shop
    container_name: juiceshop-hardened
    ports:
      - "3000:3000"
    restart: unless-stopped
    user: "1000:1000"
    read_only: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges
    tmpfs:
      - /tmp
    networks:
      - lab-net-hardened

  vuln-container-hardened:
    image: ubuntu:22.04
    container_name: vuln-container-hardened
    command: sleep infinity
    restart: unless-stopped
    user: "1000:1000"
    read_only: true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges
    # Sin docker.sock         [BIEN]
    # Sin privileged          [BIEN]
    networks:
      - lab-net-hardened

networks:
  lab-net-hardened:
    driver: bridge
```

### Levantar el stack hardenizado

```bash
docker compose -f docker-compose.hardened.yml up -d
docker ps
```

---

## Fase 3: Mitigaciones aplicadas

### Comparativa completa

| Configuracion | Vulnerable | Hardenizado | Por que importa |
|---|---|---|---|
| `docker.sock` | Montado | No montado | Sin acceso al daemon del host |
| `privileged` | true | false | Aislamiento del kernel activo |
| `cap_drop` | Ninguno | ALL | Sin capabilities del kernel |
| `cap_add` | ALL | NET_BIND_SERVICE | Solo lo estrictamente necesario |
| `read_only` | false | true | No se puede instalar nada |
| `user` | root (0) | 1000:1000 | Sin privilegios de root |
| `no-new-privileges` | No | Si | No puede escalar privilegios |
| Container escape | Posible | Imposible | Objetivo cumplido |

### Explicacion de cada mitigacion

#### 1. Eliminar docker.sock
El vector principal del escape era el socket de Docker montado dentro
del contenedor. Sin el socket, el contenedor no puede comunicarse con
el daemon Docker del host, haciendo imposible lanzar nuevos contenedores
desde dentro.

```yaml
# ANTES (vulnerable):
volumes:
  - /var/run/docker.sock:/var/run/docker.sock

# DESPUES (hardenizado):
# Sin volumes -> sin acceso al socket
```

#### 2. Eliminar privileged
El modo privilegiado desactiva practicamente todo el aislamiento de
seguridad del contenedor. Sin el, el contenedor no puede acceder a
dispositivos del host, montar sistemas de archivos arbitrarios ni
modificar el kernel.

```yaml
# ANTES (vulnerable):
privileged: true

# DESPUES (hardenizado):
# Sin privileged -> aislamiento activo
```

#### 3. cap_drop: ALL + cap_add minimas
Docker otorga por defecto un conjunto de capabilities al contenedor.
Quitarlas todas y añadir solo las estrictamente necesarias sigue el
principio de minimo privilegio.

```yaml
# ANTES (vulnerable):
cap_add:
  - ALL

# DESPUES (hardenizado):
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # solo si necesita abrir puertos < 1024
```

#### 4. read_only: true
El sistema de archivos del contenedor es de solo lectura. Esto impide
que un atacante instale herramientas, modifique binarios o persista
en el contenedor.

```yaml
read_only: true
tmpfs:
  - /tmp   # unica carpeta con escritura temporal
```

#### 5. user: "1000:1000"
El contenedor corre con un usuario sin privilegios en vez de root.
Aunque el atacante consiga ejecutar codigo, lo hara con permisos
muy limitados.

```yaml
user: "1000:1000"
```

#### 6. no-new-privileges
Impide que cualquier proceso dentro del contenedor pueda escalar
privilegios mediante setuid o setgid.

```yaml
security_opt:
  - no-new-privileges
```

---

## Fase 4: Demostracion del escape fallido

Entrando al contenedor hardenizado:

```bash
docker exec -it vuln-container-hardened bash
```

### Intento 1: instalar docker (falla por read_only)

```bash
apt update && apt install -y docker.io
# E: List directory /var/lib/apt/lists/partial is missing.
# - Acquire (30: Read-only file system)
```

El sistema de archivos es de solo lectura. No se puede instalar nada.

### Intento 2: usar docker directamente (falla por falta de cliente y socket)

```bash
docker ps
# bash: docker: command not found

docker run -it --rm -v /:/host alpine chroot /host bash
# bash: docker: command not found
```

Sin cliente Docker y sin socket montado, el escape es imposible.

### Resultado

```
ANTES (vulnerable):
docker run -v /:/host alpine chroot /host bash
-> uid=0(root) gid=0(root) -> ROOT EN EL HOST

AHORA (hardenizado):
docker run -v /:/host alpine chroot /host bash
-> bash: docker: command not found -> ESCAPE FALLIDO
```

El mismo atacante, el mismo comando, resultado completamente diferente.

---

## Nota importante: principio de minimo privilegio en contexto real

El hardening aplicado en este lab es correcto para **contenedores de
servicio** (servidores web, APIs, bases de datos). Sin embargo, en
entornos de desarrollo o trabajo interactivo, `read_only: true` no
siempre es aplicable.

En esos casos, en vez de bloquear toda escritura, se usan **volumenes
especificos** para las carpetas que necesitan escritura:

```yaml
read_only: true
volumes:
  - ./data:/home/usuario/data   # solo esta carpeta es escribible
tmpfs:
  - /tmp                        # escritura temporal
```

El principio de minimo privilegio no significa "no puede hacer nada",
sino "solo puede hacer lo estrictamente necesario para su funcion".

---

## Resumen de mitigaciones por vulnerabilidad

| Vulnerabilidad explotada | Mitigacion aplicada |
|---|---|
| docker.sock montado | Eliminado del compose |
| privileged: true | Eliminado del compose |
| cap_add: ALL | Sustituido por cap_drop: ALL |
| Sin read_only | Añadido read_only: true |
| Contenedor como root | Añadido user: 1000:1000 |
| Sin no-new-privileges | Añadido en security_opt |

Todas las mitigaciones siguen el **principio de minimo privilegio**:
cada contenedor tiene exactamente los permisos que necesita para
funcionar, y nada mas.
