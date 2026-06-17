#!/bin/bash
 
# ================================================
# hardening.sh - Aplicar hardening al stack Docker
# Autor: adriapuga
# Descripcion: Para el stack vulnerable y levanta
#              el stack hardenizado demostrando que
#              el container escape ya no funciona
# Uso: ./hardening.sh
# ================================================
 
echo "========================================"
echo "  HARDENING DEL STACK DOCKER"
echo "  Fecha: $(date)"
echo "========================================"
 
# ----------------------------------------
# FASE 1: Parar el stack vulnerable
# ----------------------------------------
echo ""
echo "[*] Parando el stack vulnerable..."
echo ""
 
cd ~/docker-security-lab
 
docker compose down
 
if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Stack vulnerable parado correctamente."
else
    echo ""
    echo "[-] Error al parar el stack vulnerable."
    exit 1
fi
 
# ----------------------------------------
# FASE 2: Levantar el stack hardenizado
# ----------------------------------------
echo ""
echo "[*] Levantando el stack hardenizado..."
echo ""
 
docker compose -f docker-compose.hardened.yml up -d
 
if [ $? -eq 0 ]; then
    echo ""
    echo "[+] Stack hardenizado levantado correctamente."
else
    echo ""
    echo "[-] Error al levantar el stack hardenizado."
    exit 1
fi
 
# ----------------------------------------
# FASE 3: Verificar el estado
# ----------------------------------------
echo ""
echo "[*] Verificando contenedores corriendo..."
echo ""
 
docker ps
 
# ----------------------------------------
# FASE 4: Comparativa de configuraciones
# ----------------------------------------
echo ""
echo "========================================"
echo "  COMPARATIVA: VULNERABLE vs HARDENIZADO"
echo "========================================"
echo ""
echo "VULNERABLE (docker-compose.yml):"
echo "  [MAL] docker.sock montado"
echo "  [MAL] privileged: true"
echo "  [MAL] cap_add: ALL"
echo "  [MAL] sin read_only"
echo "  [MAL] sin user definido (corre como root)"
echo "  [MAL] sin no-new-privileges"
echo ""
echo "HARDENIZADO (docker-compose.hardened.yml):"
echo "  [BIEN] Sin docker.sock"
echo "  [BIEN] Sin privileged"
echo "  [BIEN] cap_drop: ALL"
echo "  [BIEN] read_only: true"
echo "  [BIEN] user: 1000:1000 (sin root)"
echo "  [BIEN] no-new-privileges"
echo ""
 
# ----------------------------------------
# FASE 5: Demostrar que el escape falla
# ----------------------------------------
echo "[*] Intentando container escape en contenedor hardenizado..."
echo "[*] Comando: docker exec -it vuln-container-hardened bash"
echo ""
echo "[*] Una vez dentro, ejecuta:"
echo "    apt update       -> fallara (read_only)"
echo "    docker ps        -> fallara (sin docker.sock)"
echo "    docker run -it --rm -v /:/host alpine chroot /host bash"
echo "                     -> fallara (sin docker ni socket)"
echo ""
 
echo "========================================"
echo "  HARDENING COMPLETADO"
echo "  El container escape ya no es posible"
echo "========================================"
