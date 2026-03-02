# Documentação da Infraestrutura ASTER

Bem-vindo à documentação oficial da infraestrutura ASTER. Este projeto contém um conjunto de scripts modulares em Bash desenhados para aprovisionar, de forma automática e consistente (Infrastructure as Code - IaC), um servidor Ubuntu como o núcleo de uma rede corporativa.

## 🏗️ Arquitetura do Sistema

O servidor configurado por estes scripts assume múltiplos papéis críticos na rede:

1.  **Gateway Router & NAT:** Encaminha o tráfego da rede local (LAN) para a Internet (WAN), mascarando os IPs internos.
2.  **Samba Active Directory Domain Controller (AD DC):** Gere a autenticação centralizada de utilizadores, computadores e políticas de grupo (GPOs) compatíveis com Windows.
3.  **Servidor DNS (Interno Samba):** Resolve nomes de domínio locais (ex: `aster.local`) e atua como forwarder para a Internet.
4.  **Servidor DHCP:** Atribui automaticamente endereços IP, Gateway e DNS aos clientes da rede local.
5.  **File Server (DFS):** Providencia partilhas de ficheiros públicas e privadas com permissões integradas no Active Directory.
6.  **Backup Server:** Executa rotinas diárias consistentes de backup da base de dados LDB do Samba e ficheiros locais.
7.  **Data Intelligence & Monitorização:** Utiliza Prometheus para recolha de métricas (CPU, RAM, Disco, Rede) e Grafana para visualização em tempo real através de dashboards web.
8.  **Corporate VPN (OpenVPN):** Permite acesso remoto e seguro (Criptografia AES-256) a máquinas fora da rede local corporativa para aceder a partilhas de ficheiros, como se estivessem no escritório.

---

## 📂 Estrutura de Ficheiros

O projeto está dividido de forma modular para facilitar a manutenção e escalabilidade:

```text
infra_bash/
├── .env                    # (Ficheiro de Configuração Central: Variáveis, IPs, Passwords e Domínios)
├── setup-infra.sh          # (Orquestrador Principal: Executa todos os módulos em sequência)
└── modulos/
    ├── 01-gateway.sh       # (Configuração de NAT e Iptables)
    ├── 02-samba-ad-dc.sh   # (Instalação e Aprovisionamento do Samba AD DC nível 2012_R2)
    ├── 03-dhcp-server.sh   # (Instalação e Configuração do ISC-DHCP-Server)
    ├── 04-file-server.sh   # (Criação de Partilhas de Ficheiros e Permissões NTFS/Linux)
    ├── 05a-backups.sh      # (Criação de Cronjob e Rotina Segura de Backups .tar.gz / Samba tool)
    ├── 05b-monitorizacao.sh# (Instalação do Grafana, Prometheus DB e Node Exporter)
    └── 06-vpn-openvpn.sh   # (Servidor OpenVPN com Scripts Automáticos de criação de perfis client .ovpn)
```

---

## 🚀 Guia de Utilização (Deployment)

### Pré-requisitos
*   Um servidor a correr Ubuntu Server (versão recente recomendada, ex: 22.04 LTS ou 24.04 LTS).
*   Duas placas de rede fisicamente conectadas (WAN e LAN).
*   Privilégios de `root` (`sudo su`).
*   Acesso à Internet na interface WAN para download dos pacotes.

### Passo 1: Preparação

Se estiver a usar um computador com **Windows 10 ou 11**, pode enviar a pasta do projeto diretamente para o servidor Linux utilizando o PowerShell nativo através do protocolo SSH (garanta que o servidor tem o serviço SSH ativo):

1. **Abra o PowerShell** no seu computador Windows.
2. Navegue até à pasta onde guardou o projeto (ex: Em Transferências) e execute o comando `scp` para copiar a pasta inteira para o servidor:
   ```powershell
   scp -r .\infra_bash root@10.0.0.1:/root/
   ```
   *(Substitua `10.0.0.1` pelo IP atual do seu servidor Ubuntu e `root` pelo nome de utilizador com permissões)*.

3. Após a pasta estar no servidor, aceda-lhe via SSH ou diretamente na máquina e abra o ficheiro `.env` com um editor de texto (`nano .env` ou `vim .env`).
4. Adapte as variáveis cruciais à sua realidade física:
   *   `IF_WAN`: Nome da interface ligada à Internet (ex: `enps03`).
   *   `IF_LAN`: Nome da interface ligada à sua rede local (switch) (ex: `enps08`).
   *   `DOMAIN_REALM`: O nome de domínio desejado (ex: `aster.local`).
   *   `ADMIN_PASSWORD`: Senha do Administrador do Domínio (deve respeitar requisitos de complexidade).
   *   `OVPN_PUBLIC_IP`: IP estático do seu router da operadora (WAN externa) para os conectores VPN.

### Passo 2: Execução
Navegue até ao diretório do projeto e execute o orquestrador:

```bash
sudo su
cd /root/infra_bash/
bash ./setup-infra.sh
```

O script cuidará de tudo automaticamente. No final da execução, será apresentado um sumário no terminal com as credenciais de acesso e os URLs importantes.

---

## 📊 Monitorização e Dados (Grafana)

A nossa infraestrutura inclui Data Intelligence *out-of-the-box*.
*   **URL de Acesso:** `http://<IP_DA_LAN>:3000` (ex: `http://10.0.0.1:3000`)
*   **Utilizador Original:** `admin`
*   **Password Inicial:** Definida na variável `GRAFANA_ADMIN_PASSWORD` do `.env`.

O Prometheus já está pré-configurado como Data Source no Grafana. Recomendamos que, no primeiro login, importe um Dashboard Oficial do Node Exporter (ex: ID `1860`) na interface web para visualizar instantaneamente os gráficos de rede e carga do servidor.

---

## 🛡️ Gestão de Backups e Disaster Recovery

Os backups são controlados pelo script injetado em `/usr/local/bin/aster-backup.sh`, o qual é executado todas as madrugadas às `02:00 AM` via Cron.

*   **Localização dos Backups:** `/var/backups/infra-aster/`
*   **Retenção Padrão:** O sistema preserva os últimos 7 dias e limpa automaticamente os mais antigos.
*   **O que está incluído:** Base de dados do Active Directory (LDB), GPOs (Sysvol), Ficheiros Partilhados e Ficheiros de Configuração críticos (dhcpd.conf, smb.conf).

### Recomendações de Segurança Críticas:
A arquitetura atual guarda os backups no próprio disco do servidor. É imperativo que implemente um mecanismo (como o `rclone`, AWS S3 ou cópia via `rsync` para um Storage NAS paralelo) para retirar regularmente os pacotes `.tar.gz` da série `/var/backups/infra-aster/` para um local de armazenamento externo (Off-site Backup).

---

## 🌎 Como Adicionar Utilizadores à VPN

Para garantir grande produtividade, criámos um assistente rápido incluído no próprio servidor que faz todo o trabalho de gerar certificados e criptografia para os seus colaboradores poderem trabalhar de casa.

Para criar o perfil do **joao.silva**, basta digitar na linha de comandos:
```bash
sudo aster-add-vpn-user.sh joao.silva
```
O sistema vai processar uma chave privada `.ovpn` (ex: `/root/vpn-clients/joao.silva/joao.silva.ovpn`). Envie esse ficheiro confidencialmente para ele. O colaborador apenas terá de descarregar a aplicação 'OpenVPN Connect' (Windows/Mac/Android) e importar esse ficheiro. Assim que se conectar, o computador dele receberá um IP no formato `10.8.0.x` e conseguirá pingar os servidores e abrir os documentos do Samba.

---

## 🔮 Futuras Extensões e Roadmap Técnico

A infraestrutura foi construída com mentalidade de evolução. Ficam aqui as recomendações do Arquiteto (ex: `07-cloud-sync.sh`):

1.  **Sincronização Cloud dos Backups:** Automatizar o envio dos snapshots noturnos para a AWS S3 ou Backblaze.
2.  **High Availability (DC Secundário):** Aprovisionamento de um segundo servidor Samba num nó secundário para replicação contínua, prevenindo falhas de autenticação se este servidor de Gateway falhar.
