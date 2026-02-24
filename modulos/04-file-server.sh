#!/bin/bash
# ==============================================================================
# Script: 04-file-server.sh
# ==============================================================================

source ./.env

echo "[MÓDULO 4] A configurar o Servidor de Partilha de Ficheiros (Samba File Server)..."

# 1. Criar a estrutura base de diretórios
echo "A criar diretórios base em ${SHARE_BASE_DIR}..."
mkdir -p "${SHARE_BASE_DIR}/${PUBLIC_SHARE_NAME}"
mkdir -p "${SHARE_BASE_DIR}/${RESTRICTED_SHARE_NAME}"

# 2. Configurar as permissões no sistema de ficheiros
# A partilha pública será acessível a todos os utilizadores autenticados do domínio ("Domain Users")
chown -R root:"Domain Users" "${SHARE_BASE_DIR}/${PUBLIC_SHARE_NAME}"
chmod -R 2770 "${SHARE_BASE_DIR}/${PUBLIC_SHARE_NAME}" # SGID + rwx para dono e grupo

# A partilha restrita será acessível apenas ao grupo especificado
chown -R root:"${RESTRICTED_GROUP}" "${SHARE_BASE_DIR}/${RESTRICTED_SHARE_NAME}"
chmod -R 2770 "${SHARE_BASE_DIR}/${RESTRICTED_SHARE_NAME}"

# 3. Adicionar as configurações ao ficheiro de configuração do Samba (smb.conf)
SMB_CONF="/etc/samba/smb.conf"

echo "A adicionar configurações das partilhas no smb.conf..."

# Backup do smb.conf caso seja necessário reconstruir
cp $SMB_CONF ${SMB_CONF}.fs.backup

cat <<EOF >> $SMB_CONF

# =====================================
# Configurações de Partilha de Ficheiros
# =====================================

[${PUBLIC_SHARE_NAME}]
   path = ${SHARE_BASE_DIR}/${PUBLIC_SHARE_NAME}
   read only = no
   # Qualquer membro do Domínio pode aceder
   valid users = @"${DOMAIN_NETBIOS}\Domain Users"
   force create mode = 0660
   force directory mode = 2770

[${RESTRICTED_SHARE_NAME}]
   path = ${SHARE_BASE_DIR}/${RESTRICTED_SHARE_NAME}
   read only = no
   # Apenas o grupo permitido (ex: Domain Admins)
   valid users = @"${DOMAIN_NETBIOS}\\${RESTRICTED_GROUP}"
   force create mode = 0660
   force directory mode = 2770

EOF

# 4. Aplicar as alterações
echo "A recarregar as configurações do Samba AD DC..."
smbcontrol all reload-config

echo "[MÓDULO 4] Partilhas de Ficheiros configuradas com sucesso!"
echo "- Partilha Pública: \\\\${IP_LAN}\\${PUBLIC_SHARE_NAME}"
echo "- Partilha Restrita: \\\\${IP_LAN}\\${RESTRICTED_SHARE_NAME}"
