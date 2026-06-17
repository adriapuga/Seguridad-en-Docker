#!/bin/bash

# ================================================
# recon.sh - Reconocimiento automatizado
# Autor: adriapuga
# Descripcion: Automatiza la fase de reconocimiento
# Uso: ./recon.sh <IP_OBJETIVO>
# ================================================

# Recibir la IP como argumento
TARGET=$1

# Comprobar que se ha pasado un argumento
if [ -z "$TARGET" ]; then
    echo "Uso: ./recon.sh <IP_OBJETIVO>"
    echo "Ejemplo: ./recon.sh 192.168.122.95"
    exit 1
fi

# Crear carpeta de reportes
FECHA=$(date +%Y%m%d_%H%M%S)
REPORTE="recon_${TARGET}_${FECHA}.txt"
mkdir -p ~/docker-security-lab/reports

echo "[*] El reporte se guardara en: ~/docker-security-lab/reports/$REPORTE"
exec > >(tee ~/docker-security-lab/reports/$REPORTE) 2>&1

echo "========================================"
echo "  RECONOCIMIENTO INICIADO"
echo "  Objetivo: $TARGET"
echo "========================================"

# ----------------------------------------
# FASE 1: Verificar conectividad
# ----------------------------------------
echo ""
echo "[*] Verificando conectividad con $TARGET..."
echo ""

ping -c 3 $TARGET

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Host activo. Continuando reconocimiento..."
else
    echo ""
    echo "[-] Host no responde al ping. Puede estar caido o filtrar ICMP."
    echo "[-] Continuando de todas formas..."
fi

# ----------------------------------------
# FASE 2: Escaneo de puertos con nmap
# ----------------------------------------
echo ""
echo "[*] Escaneando puertos con nmap..."
echo ""

nmap -sV -p- --open $TARGET

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Escaneo nmap completado."
else
    echo ""
    echo "[-] Error durante el escaneo nmap."
fi

# ----------------------------------------
# FASE 3: Analisis de headers HTTP
# ----------------------------------------
echo ""
echo "[*] Analizando headers HTTP del puerto 3000..."
echo ""

curl -I http://$TARGET:3000

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Analisis de headers completado."
else
    echo ""
    echo "[-] No se pudo conectar al puerto 3000."
fi

echo ""
echo "[*] Analizando headers HTTP del puerto 80..."
echo ""

curl -I http://$TARGET:80

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Analisis de headers completado."
else
    echo ""
    echo "[-] No se pudo conectar al puerto 80."
fi

# ----------------------------------------
# FASE 4: Fingerprinting con whatweb
# ----------------------------------------
echo ""
echo "[*] Fingerprinting de tecnologias con whatweb..."
echo ""

whatweb http://$TARGET:3000
whatweb http://$TARGET:80

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Fingerprinting completado."
else
    echo ""
    echo "[-] Error durante el fingerprinting."
fi

# ----------------------------------------
# FASE 5: Enumeracion de rutas con gobuster
# ----------------------------------------
echo ""
echo "[*] Enumerando rutas en puerto 3000..."
echo ""

gobuster dir \
    -u http://$TARGET:3000 \
    -w /usr/share/wordlists/dirb/common.txt \
    -q \
    --no-error \
    --xl  9903

echo ""
echo "[*] Enumerando rutas en puerto 80..."
echo ""

gobuster dir \
    -u http://$TARGET:80 \
    -w /usr/share/wordlists/dirb/common.txt \
    -q \
    --no-error 
echo ""
echo "[+] Enumeracion de rutas completada."
