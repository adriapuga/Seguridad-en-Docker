# 02 - Despliegue del stack vulnerable

## Objetivo

Desplegar el entorno vulnerable sobre el servidor Debian 12 usando Docker Compose.
El stack incluye dos contenedores:

- **juiceshop**: aplicacion web vulnerable (OWASP Juice Shop)
- **vuln-container**: contenedor Ubuntu mal configurado a proposito (vector de container escape)

Ambos comparten una red interna llamada `lab-net`.

---

## Estructura del proyecto

```
~/docker-security-lab/
└── docker-compose.yml
```

Crear la carpeta del proyecto:

```bash
mkdir -p ~/docker-security-lab
cd ~/docker-security-lab
```

---

## docker-compose.yml

```yaml
services:
  juiceshop:
    image: bkimminich/juice-shop
    container_name: juiceshop
    ports:
      - "3000:3000"
    restart: unless-stopped
    networks:
      - lab-net

  vuln-container:
    image: ubuntu:22.04
    container_name: vuln-container
    command: sleep infinity
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock   # [MAL] Misconfiguración 1
    privileged: true                                 # [MAL] Misconfiguración 2
    cap_add:
      - ALL                                          # [MAL] Misconfiguración 3
    networks:
      - lab-net

networks:
  lab-net:
    driver: bridge
```

---

## Misconfiguraciones introducidas a proposito

El contenedor `vuln-container` tiene tres misconfiguraciones criticas que seran
explotadas en la fase ofensiva:

| # | Misconfiguración | Riesgo | Por que es peligrosa |
|---|---|---|---|
| 1 | `docker.sock` montado | Critico | El contenedor controla el daemon Docker del host → container escape directo |
| 2 | `privileged: true` | Critico | Desactiva el aislamiento; el contenedor accede a `/dev`, puede montar sistemas de archivos del host |
| 3 | `cap_add: ALL` | Critico | Otorga todas las capabilities del kernel (CAP_SYS_ADMIN, CAP_SYS_MODULE...) |

---

## Despliegue

Levantar el stack:

```bash
docker compose up -d
```

La primera vez descarga las imagenes de Docker Hub:
- `bkimminich/juice-shop` (~400 MB)
- `ubuntu:22.04` (~80 MB)

Verificar que los dos contenedores estan corriendo:

```bash
docker ps
```

Resultado esperado:

```
CONTAINER ID   IMAGE                    STATUS         PORTS                    NAMES
xxxxxxxxxxxx   bkimminich/juice-shop    Up X seconds   0.0.0.0:3000->3000/tcp   juiceshop
xxxxxxxxxxxx   ubuntu:22.04             Up X seconds                            vuln-container
```

---

## Verificacion del stack

### Juice Shop responde

```bash
curl -I http://localhost:3000
```

Resultado esperado: `HTTP/1.1 200 OK`

### Red interna creada

```bash
docker network ls
```

Debe aparecer `docker-security-lab_lab-net` de tipo `bridge`.

### IPs internas de los contenedores

```bash
docker inspect juiceshop -f '{{.NetworkSettings.Networks.docker-security-lab_lab-net.IPAddress}}'
docker inspect vuln-container -f '{{.NetworkSettings.Networks.docker-security-lab_lab-net.IPAddress}}'
```

---

## Politica de reinicio

Ambos contenedores tienen `restart: unless-stopped`, lo que significa que
se volveran a arrancar automaticamente tras un reinicio del host.

Sin esta politica, los contenedores quedarian parados tras apagar la VM
y habria que levantarlos manualmente con `docker compose up -d`.

---

## Redes Docker generadas

Al levantar el stack, Docker crea las siguientes interfaces de red en el host:

| Interfaz | Proposito |
|---|---|
| `docker0` | Bridge por defecto de Docker (no usado en este lab) |
| `br-xxxxxxxxxx` | Bridge de `lab-net` (nuestra red interna) |
| `veth*` | Interfaces virtuales de cada contenedor conectadas al bridge |

Verificar con:

```bash
ip a
```

---

## Diagrama de red

```
                 HOST (192.168.122.95)
                        |
          +-------------+-------------+
          |                           |
    [lab-net bridge]           [enp1s0 - red fisica]
    172.18.0.0/16                192.168.122.0/24
          |                           |
    +-----+-----+                     |
    |           |               [Kali atacante]
[juiceshop]  [vuln-container]   192.168.122.???
172.18.0.2   172.18.0.3
puerto 3000
(mapeado al
host:3000)
```

Desde Kali, solo es accesible la IP del host (`192.168.122.95`).
Los contenedores son alcanzables unicamente a traves de los puertos
mapeados o desde dentro de la red `lab-net`.
