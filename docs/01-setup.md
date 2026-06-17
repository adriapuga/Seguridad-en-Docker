# 01 - Setup del entorno

## Sistema operativo

| Campo | Valor |
|---|---|
| Distribución | Debian GNU/Linux 12 (bookworm) |
| Kernel | 6.1.0-48-amd64 |
| Arquitectura | x86_64 |
| IP del servidor | 192.168.122.95 |
| Hipervisor | QEMU/KVM (libvirt) |

## Instalación de Docker

### 1. Actualizar el sistema

```bash
apt update && apt upgrade -y
```

### 2. Instalar dependencias

```bash
apt install -y ca-certificates curl gnupg
```

### 3. Añadir la clave GPG oficial de Docker

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
```

### 4. Añadir el repositorio oficial de Docker

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Verificar que el archivo quedó bien formado:

```bash
cat /etc/apt/sources.list.d/docker.list
```

Resultado esperado: deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable

### 5. Instalar Docker Engine

```bash
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 6. Habilitar el servicio y verificar

```bash
systemctl enable --now docker
systemctl status docker
```

Resultado esperado: `Active: active (running)`

### 7. Test de funcionamiento

```bash
docker run hello-world
```

Resultado esperado: mensaje `Hello from Docker!`

## Notas de seguridad

> El daemon de Docker corre como root en el host. Cualquier usuario con acceso
> al socket `/var/run/docker.sock` tiene control total sobre el sistema.
> Este vector se demostrara en la fase de container escape.
