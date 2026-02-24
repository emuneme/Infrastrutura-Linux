#!/bin/bash
# ==============================================================================
# Script: 06-vpn-openvpn.sh
# Descrição: Instala e configura um servidor OpenVPN corporativo.
# Integra os clientes remotos com o DNS interno do AD e cria script auxiliar
# para a geração de perfis de utilizador (.ovpn).
# ==============================================================================

source ./.env

echo "[MÓDULO 6] A instalar e configurar VPN Corporativa (OpenVPN)..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y openvpn easy-rsa ufw iptables-persistent

# 1. Configurar Easy-RSA (PKI - Public Key Infrastructure)
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

# Inicializar PKI e gerar chaves sem password (para automação)
export EASYRSA_BATCH=1 # Evita prompts interativos
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey secret ta.key

# Copiar os certificados gerados para o diretório do servidor OpenVPN
cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem ta.key /etc/openvpn/server/

# 2. Criar a configuração do Servidor OpenVPN (server.conf)
echo "A gerar /etc/openvpn/server/server.conf..."
cat <<EOF > /etc/openvpn/server/server.conf
port ${OVPN_PORT}
proto ${OVPN_PROTO}
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0

# Subrede da VPN (Túnel)
server ${OVPN_SUBNET} ${OVPN_NETMASK}

# Forçar os clientes a usar o Samba AD como DNS e passar as rotas da LAN
push "route ${SUBNET_LAN} ${NETMASK}"
push "dhcp-option DNS ${IP_LAN}"
push "dhcp-option DOMAIN ${DOMAIN_REALM}"

keepalive 10 120
cipher AES-256-GCM
ncp-ciphers AES-256-GCM:AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

# 3. Configurar Regras de Routing e NAT para a VPN
echo "A aplicar regras de Iptables para o tráfego VPN..."
# Permitir tráfego da rede VPN (tun0) para a Internet/WAN e para a LAN
iptables -t nat -A POSTROUTING -s ${OVPN_SUBNET}/24 -o ${IF_WAN} -j MASQUERADE
iptables -A FORWARD -i tun0 -o ${IF_LAN} -j ACCEPT
iptables -A FORWARD -i ${IF_LAN} -o tun0 -j ACCEPT
netfilter-persistent save

# 4. Iniciar o serviço
echo "A ativar o serviço OpenVPN..."
systemctl enable openvpn-server@server.service
systemctl restart openvpn-server@server.service

# 5. Criar Script Auxiliar (Gerador de .ovpn para os funcionários)
HELPER_SCRIPT="/usr/local/bin/aster-add-vpn-user.sh"
echo "A criar utilitário em ${HELPER_SCRIPT} para gerar perfis móveis/PC..."
cat <<'EOF' > $HELPER_SCRIPT
#!/bin/bash
# =======================================================================
# Utilitário: aster-add-vpn-user.sh
# Uso: sudo aster-add-vpn-user.sh [nome_do_colaborador]
# Descrição: Gera ficheiros .ovpn prontos a enviar aos funcionários.
# =======================================================================
source /root/infra_bash/.env

if [ -z "$1" ]; then
    echo "Erro: Precisa de indicar o nome do utilizador."
    echo "Uso: $0 joao.silva"
    exit 1
fi

CLIENT=$1
EASYRSA_DIR="/etc/openvpn/easy-rsa"
OUTPUT_DIR="/root/vpn-clients/$CLIENT"

mkdir -p $OUTPUT_DIR
cd $EASYRSA_DIR

# Substituir public IP se não foi mudado no .env
IP_TO_CONNECT="${OVPN_PUBLIC_IP}"
if [ "$IP_TO_CONNECT" == "SEU_IP_PUBLICO_AQUI" ]; then
    IP_TO_CONNECT=$(curl -s ifconfig.me)
fi

export EASYRSA_BATCH=1
./easyrsa gen-req "$CLIENT" nopass > /dev/null
./easyrsa sign-req client "$CLIENT" > /dev/null

BASE_CONFIG="
client
dev tun
proto ${OVPN_PROTO}
remote ${IP_TO_CONNECT} ${OVPN_PORT}
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
"

echo "$BASE_CONFIG" > "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "<ca>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
cat pki/ca.crt >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "</ca>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "<cert>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
cat pki/issued/${CLIENT}.crt >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "</cert>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "<key>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
cat pki/private/${CLIENT}.key >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "</key>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "<tls-auth>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
cat ta.key >> "${OUTPUT_DIR}/${CLIENT}.ovpn"
echo "</tls-auth>" >> "${OUTPUT_DIR}/${CLIENT}.ovpn"

echo -e "\033[0;32m[SUCESSO] O perfil VPN para '$CLIENT' foi criado!\033[0m"
echo -e "Envie o ficheiro seguro abaixo para o utilizador:"
echo -e "👉 \033[1;33m${OUTPUT_DIR}/${CLIENT}.ovpn\033[0m"
EOF
chmod +x $HELPER_SCRIPT

echo "[MÓDULO 6] VPN OpenVPN Aprovisionada! Rede $OVPN_SUBNET conectada."
echo "Para gerar o acesso a um funcionário, corra o comando:"
echo "sudo aster-add-vpn-user.sh nome_do_utilizador"
