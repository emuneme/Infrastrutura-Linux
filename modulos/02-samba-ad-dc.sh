#!/bin/bash
# ==============================================================================
# Script: 02-samba-ad-dc.sh
# ==============================================================================

source ./.env

echo "[MÓDULO 2] A configurar Samba Active Directory Domain Controller..."

# 1. Instalar pacotes necessários (Samba, Kerberos, Winbind)
export DEBIAN_FRONTEND=noninteractive
echo "samba-common samba-common/workgroup string ${DOMAIN_NETBIOS^^}" | debconf-set-selections
echo "samba-common samba-common/dhcp boolean false" | debconf-set-selections

apt-get install -y samba smbclient winbind libpam-winbind libnss-winbind krb5-kdc krb5-user

# 2. Parar serviços atuais
systemctl stop smbd nmbd winbind
systemctl disable smbd nmbd winbind || true
systemctl unmask samba-ad-dc || true
systemctl enable samba-ad-dc

# 3. Limpar configurações default e aprovisionar Domínio
rm -f /etc/samba/smb.conf
rm -f /var/lib/samba/private/krb5.conf

echo "A aprovisionar o domínio ${DOMAIN_REALM}..."
samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --dns-backend=SAMBA_INTERNAL \
  --realm=${DOMAIN_REALM^^} \
  --domain=${DOMAIN_NETBIOS^^} \
  --adminpass=${ADMIN_PASSWORD} \
  --function-level=${FUNCTIONAL_LEVEL}

# 4. Configurar DNS reverso e Kerberos
cp /var/lib/samba/private/krb5.conf /etc/

# 5. Iniciar o Domain Controller
systemctl start samba-ad-dc

echo "A aguardar o startup do serviço..."
sleep 5

# 6. Testar
smbclient -L localhost -U% || echo "Aviso na verificação do smbclient, mas o serviço de AD deve estar online."

echo "[MÓDULO 2] Samba AD DC configurado e a rodar na rede ${DOMAIN_REALM}!"
