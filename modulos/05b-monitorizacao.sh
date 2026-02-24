#!/bin/bash
# ==============================================================================
# Script: 05b-monitorizacao.sh
# Descrição: Instala o Prometheus (Base de Dados Numérica),
# Node Exporter (Extração de Métricas do SO e Rede) e o 
# Grafana (Dashboard Analítico) na Máquina Ubuntu.
# ==============================================================================

source ./.env

echo "[MÓDULO 5B] A instalar Stack de Monitorização (Prometheus + Grafana)..."

# Instalar pacotes base
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y apt-transport-https software-properties-common wget dirmngr

# 1. Instalar Prometheus & Node Exporter
# Em distros recentes do Ubuntu o apt gere bem estas versões estáveis
echo "A instalar Prometheus DB e Node Exporter..."
apt-get install -y prometheus prometheus-node-exporter

# Iniciar e ativar os serviços do Prometheus DB
systemctl enable prometheus prometheus-node-exporter
systemctl start prometheus prometheus-node-exporter

# 2. Instalar Grafana (Modo Enterprise Open Source)
echo "A adicionar repósitorio do Grafana Labs..."
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update -qq

echo "A instalar Grafana Server..."
apt-get install -y grafana

# 3. Configurar a Password de Admin Customizada do Grafana (a partir do .env)
# Através do CLI do grafana
systemctl start grafana-server
systemctl enable grafana-server

# O Grafana demora alguns segundos para inicializar a BD SQLite interna
sleep 15
echo "A configurar password do administrador web ('admin')..."
grafana-cli admin reset-admin-password "$GRAFANA_ADMIN_PASSWORD"

# 4. Aprovisionamento Automático da Fonte de Dados (Prometheus) para o Grafana
# Desta forma não precisa de configurar isto à mão na interface web
PROVISION_DIR="/etc/grafana/provisioning/datasources"
mkdir -p $PROVISION_DIR

cat <<EOF > $PROVISION_DIR/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    # Como está na mesma máquina, ouve localmente no porto 9090
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF

echo "A recarregar Grafana com a nova fonte de dados prometheus..."
systemctl restart grafana-server

echo "[MÓDULO 5B] Stack Analítica pronta!"
echo "Aceda ao seu dashboard em:"
echo "👉 http://${IP_LAN}:3000"
echo "Login: admin"
echo "Password: ${GRAFANA_ADMIN_PASSWORD}"
