#!/bin/bash

# ================================================
# detection.sh - Instalacion y demo de Falco y Trivy
# Autor: adriapuga
# Descripcion: Instala Falco y Trivy, escanea las
#              imagenes y demuestra la deteccion
#              en tiempo real del container escape
# Uso: ./detection.sh
# ================================================

echo "========================================"
echo "  DETECCION Y MONITORIZACION"
echo "  Fecha: $(date)"
echo "========================================"

# ----------------------------------------
# FASE 1: Instalar Trivy
# ----------------------------------------
echo ""
echo "[*] Instalando Trivy..."
echo ""

apt install -y wget apt-transport-https gnupg 2>/dev/null

wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb generic main" | \
    tee /etc/apt/sources.list.d/trivy.list

apt update -qq
apt install -y trivy

echo "[+] Trivy instalado: $(trivy --version | head -1)"

# ----------------------------------------
# FASE 2: Escanear imagenes con Trivy
# ----------------------------------------
echo ""
echo "[*] Escaneando imagen bkimminich/juice-shop..."
echo ""

trivy image --severity HIGH,CRITICAL bkimminich/juice-shop 2>&1 | \
    grep -E "Total:|CRITICAL|HIGH" | head -20

echo ""
echo "[*] Escaneando imagen ubuntu:22.04..."
echo ""

trivy image ubuntu:22.04 2>&1 | tail -5

echo ""
echo "[+] Escaneo de imagenes completado."

# ----------------------------------------
# FASE 3: Instalar Falco
# ----------------------------------------
echo ""
echo "[*] Instalando Falco..."
echo ""

curl -fsSL https://falco.org/repo/falcosecurity-packages.asc -o /tmp/falco.asc
/usr/bin/gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg /tmp/falco.asc

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
https://download.falco.org/packages/deb stable main" | \
    tee /etc/apt/sources.list.d/falcosecurity.list

apt update -qq
apt install -y falco

echo "[+] Falco instalado: $(falco --version 2>/dev/null | grep 'Falco version')"

# ----------------------------------------
# FASE 4: Verificar Falco corriendo
# ----------------------------------------
echo ""
echo "[*] Verificando estado de Falco..."
echo ""

systemctl status falco-modern-bpf | grep -E "Active:|version"

echo ""
echo "[+] Falco activo y monitorizando."

# ----------------------------------------
# FASE 5: Instrucciones para la demo
# ----------------------------------------
echo ""
echo "========================================"
echo "  INSTRUCCIONES PARA LA DEMO DE FALCO"
echo "========================================"
echo ""
echo "[*] Para ver los logs de Falco en tiempo real:"
echo "    journalctl -fu falco-modern-bpf"
echo ""
echo "[*] En otra terminal, simula el ataque:"
echo "    docker exec -it vuln-container bash"
echo "    apt update && apt install -y docker.io"
echo "    docker run -it --rm -v /:/host alpine chroot /host bash"
echo ""
echo "[*] Falco generara alertas CRITICAL para cada accion sospechosa."
echo ""
echo "========================================"
echo "  DETECCION COMPLETADA"
echo "========================================"
