#!/bin/bash
# ==============================================================================
# Script: 03-dhcp-server.sh
# ==============================================================================

source ./.env

echo "[MÓDULO 3] A configurar servidor DHCP..."

# 1. Instalar isc-dhcp-server
export DEBIAN_FRONTEND=noninteractive
apt-get install -y isc-dhcp-server

# 2. Configurar a interface no default file
sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"${IF_LAN}\"/g" /etc/default/isc-dhcp-server

# 3. Configurar /etc/dhcp/dhcpd.conf
DHCP_CONF="/etc/dhcp/dhcpd.conf"

# Criar backup do conf original
mv $DHCP_CONF ${DHCP_CONF}.backup

cat <<EOF > $DHCP_CONF
option domain-name "${DOMAIN_REALM}";
option domain-name-servers ${DHCP_DNS1}, ${DHCP_DNS2};

default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet ${SUBNET_LAN} netmask ${NETMASK} {
  range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
  option routers ${DHCP_GATEWAY};
  option broadcast-address 10.0.0.255;
}
EOF

# 4. Reiniciar e ativar o serviço DHCP
echo "A iniciar o serviço DHCP na porta LAN (${IF_LAN})..."
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

echo "[MÓDULO 3] DHCP configurado e a distribuir IPs de ${DHCP_RANGE_START} a ${DHCP_RANGE_END}!"
