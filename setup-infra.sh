#!/bin/bash
# ==============================================================================
# Script: setup-infra.sh
# Descrição: Orquestrador da Infraestrutura (Gateway, Samba, DHCP, FS, Backup, Grafana)
# ==============================================================================

set -e

if [ -f "./.env" ]; then
    source ./.env
else
    echo -e "\033[0;31m[ERRO] Ficheiro .env não encontrado. Execute o script no diretório raiz da infra.\033[0m"
    exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_error() { echo -e "${RED}[ERRO] $1${NC}"; }

if [[ $EUID -ne 0 ]]; then
   log_error "Este script tem de ser executado como root (sudo)."
   exit 1
fi

log_info "A iniciar o aprovisionamento da infraestrutura ASTER..."

chmod +x ./modulos/*.sh

log_info "Passo 1: A configurar Gateway e Firewall..."
./modulos/01-gateway.sh || { log_error "Falha no Passo 1"; exit 1; }

log_info "Passo 2: A instalar Samba AD DC..."
./modulos/02-samba-ad-dc.sh || { log_error "Falha no Passo 2"; exit 1; }

log_info "Passo 3: A configurar Servidor DHCP..."
./modulos/03-dhcp-server.sh || { log_error "Falha no Passo 3"; exit 1; }

log_info "Passo 4: A configurar Partilhas de Ficheiros..."
./modulos/04-file-server.sh || { log_error "Falha no Passo 4"; exit 1; }

log_info "Passo 5A: A configurar Processos de Backup..."
./modulos/05a-backups.sh || { log_error "Falha no Passo 5A"; exit 1; }

log_info "Passo 5B: A instalar Grafana & Prometheus (Monitorização)..."
./modulos/05b-monitorizacao.sh || { log_error "Falha no Passo 5B"; exit 1; }

log_info "Passo 6: A instalar VPN Corporativa (OpenVPN)..."
./modulos/06-vpn-openvpn.sh || { log_error "Falha no Passo 6"; exit 1; }

log_info "=========================================================="
log_info "🚀 Aprovisionamento concluído com SUCESSO! A infraestrutura está pronta."
echo "Domínio AD: $DOMAIN_REALM"
echo "Password Admin AD: $ADMIN_PASSWORD"
echo "Dashboard Monitorização: http://${IP_LAN}:3000"
echo "Grafana Admin Password: $GRAFANA_ADMIN_PASSWORD"
log_info "=========================================================="
