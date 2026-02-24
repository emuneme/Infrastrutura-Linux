#!/bin/bash
# ==============================================================================
# Script: 01-gateway.sh
# ==============================================================================

source ./.env

echo "[MÓDULO 1] A configurar o servidor como Gateway Router..."

# 1. Configurar IP Estático na LAN (Tratamento via Netplan - Ajustável dependendo do Ubuntu)
echo "A garantir que a interface LAN ($IF_LAN) está ativa e com IP $IP_LAN..."
ip addr add $IP_LAN/24 dev $IF_LAN || true
ip link set dev $IF_LAN up

# 2. Ativar o IP Forwarding
echo "A ativar IP Forwarding no kernel..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p

# 3. Configurar IPTables para NAT (Masquerade para partilha de Internet)
echo "A aplicar regras de Iptables..."
iptables -t nat -A POSTROUTING -o $IF_WAN -j MASQUERADE
iptables -A FORWARD -i $IF_WAN -o $IF_LAN -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $IF_LAN -o $IF_WAN -j ACCEPT

# 4. Guardar as regras
echo "A instalar e guardar regras no netfilter-persistent..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y iptables-persistent netfilter-persistent -qq
netfilter-persistent save

echo "[MÓDULO 1] Configuração de Gateway e NAT concluída!"
