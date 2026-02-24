#!/bin/bash
# ==============================================================================
# Script: 05-backup-rotina.sh
# Descrição: Instalação das ferramentas de compressão e agendamento
# do script diário para backup consistente do Samba AD DC e dos ficheiros.
# ==============================================================================

source ./.env

echo "[MÓDULO 5A] A configurar Rotina Profissional de Backups..."

# 1. Garantir que o diretório de destino existe
mkdir -p "$BACKUP_DEST_DIR"
chmod 700 "$BACKUP_DEST_DIR"

# 2. Instalar ferramentas de compressão
export DEBIAN_FRONTEND=noninteractive
apt-get install -y tar gzip rsync

# 3. Criar o script que fará o backup atual todos os dias às 02h00
BACKUP_SCRIPT_PATH="/usr/local/bin/aster-backup.sh"

cat <<'EOF' > $BACKUP_SCRIPT_PATH
#!/bin/bash
# Comando de Backup do ASTER - Executado automaticamente via Cron

# Carregar variáveis do ficheiro principal (caminho fixo para o cron localizá-lo)
source /root/infra_bash/.env || { echo "Falha a carregar .env"; exit 1; }

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DAILY_DIR="${BACKUP_DEST_DIR}/${TIMESTAMP}"

echo "A iniciar o backup diário em $DAILY_DIR..."
mkdir -p "$DAILY_DIR"

# Passo A: Backup Consistente do Active Directory (Base de Dados LDB + Sysvol)
# ATENÇÃO: Nunca copiar manualmente. Usar sempre 'samba-tool domain backup'
samba-tool domain backup offline --targetdir="$DAILY_DIR"

# Passo B: Backup dos Dados do File Server
# Comprime e guarda todos os ficheiros respeitando as permissões
tar -czpf "${DAILY_DIR}/fileserver_shares.tar.gz" -C / srv/samba/shares

# Passo C: Backup de Configurações Críticas do SO
tar -czpf "${DAILY_DIR}/etc_configs.tar.gz" -C / etc/samba/smb.conf etc/dhcp/dhcpd.conf etc/iptables

# Passo D: Retenção - Apagar backups mais antigos que o definido (Ex: 7 dias)
find "$BACKUP_DEST_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} +

echo "Backup concluído com sucesso."
EOF

# Tornar o script executável
chmod +x $BACKUP_SCRIPT_PATH

# 4. Agendar a tarefa no Cron (Executar diariamente às 02:00 AM)
# Remove configuração anterior se existir, para não duplicar entradas
crontab -l | grep -v 'aster-backup.sh'  | crontab -
# Adiciona a nova tarefa
(crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT_PATH >> /var/log/aster_backup.log 2>&1") | crontab -

echo "[MÓDULO 5A] Rotina de backup instalada! Corre diariamente às 02h00."
echo "Destino: ${BACKUP_DEST_DIR}"
