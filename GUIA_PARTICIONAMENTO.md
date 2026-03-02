# 💽 Guia de Particionamento e Gestão de Discos (LVM)

Um planeamento sólido das partições do servidor Ubuntu é a fundação para a estabilidade, segurança e performance da sua infraestrutura corporativa (Active Directory, Partilhas de Ficheiros, Backups e Monitorização).

Este guia detalha as melhores práticas recomendadas pela arquitetura ASTER para a divisão do seu armazenamento físico.

---

## 1. A Filosofia LVM (Logical Volume Manager)

Em vez de particionar diretamente o disco rígido (partições estáticas que são difíceis de redimensionar no futuro), recomendamos sempre o uso de **LVM** (*Logical Volume Manager*).

O LVM introduz uma camada de abstração que lhe permite aumentar o espaço das suas partições a quente (*hot resize*), adicionando novos discos físicos à máquina sem necessitar de a reiniciar.

### 🏛️ Arquitetura de Armazenamento Recomendada

```mermaid
flowchart TD
    subgraph Camada Física (Hardware)
        disk1[(Disco Físico 1\n /dev/sda)]
        disk2[(Disco Físico 2\n /dev/sdb - Opcional para RAID ou Extensão)]
    end

    subgraph LVM: Volume Group (VG)
        vg[Volume Group: `vg_aster`\nAgrupa os discos físicos num grande *pool* de espaço]
    end

    subgraph LVM: Logical Volumes (LV)
        lv_root[LV: `lv_root`\n/ \nRaiz do Sistema (OS)]
        lv_var[LV: `lv_var`\n/var \nLogs, Bases de Dados, Backups]
        lv_samba[LV: `lv_samba`\n/srv/samba \nPartilhas de Ficheiros (DFS)]
        lv_swap[LV: `lv_swap`\n[SWAP]\nMemória Virtual]
    end

    disk1 --> vg
    disk2 -.-> vg
    vg --> lv_root
    vg --> lv_var
    vg --> lv_samba
    vg --> lv_swap
```

---

## 2. Isolamento de Contextos Críticos

Porque não devemos instalar tudo numa única partição `/` (Raiz)?

1.  **Explosão de Logs previne a Queda do Sistema:** Se um serviço (ex: Monitorização ou Samba) tiver um comportamento anómalo e gerar GBs de logs em `/var/log`, encherá o disco. Se o `/var` estiver agrupado com a raiz `/`, o servidor deixará de conseguir arrancar, atualizar-se ou autenticar novos utilizadores. Isolando num *Logical Volume* dedicado, mesmo que atinja os 100%, o sistema operativo em `/` continua com espaço e fluído.
2.  **Segurança dos Dados (Samba):** Colocar as partilhas dos utilizadores numa partição dedicada (`/srv/samba`) facilita a gestão de permissões (ACLs), backups independentes e a criação de *snapshots* (LVM snapshots) que protegem contra *Ransomware*.
3.  **Sistema de Ficheiros Adequado:**
    *   Para o Samba AD DC rolar perfeitamente, a partição onde reside o Sysvol e os Ficheiros **deve** usar preferencialmente o sistema **EXT4** (ou XFS) e ter suporte nativo a *user_xattr* e *acl* ativados.

---

## 3. Topologia e Dimensionamento Sugerido

Abaixo apresentam-se dois cenários típicos para Pequenas e Médias Empresas (PMEs). Adapte conforme a sua realidade financeira.

> [!IMPORTANT]
> A partição `/boot/efi` (responsável pelo boot UEFI moderno) não gere a abstração LVM diretamente no Ubuntu Installer. Deve ser criada isolada no disco antes da camada LVM.

### Cenário A: Servidor Padrão (Disco de 500GB)

Tamanho moderado, pensado para escritórios de 10 a 50 utilizadores.

| Ponto de Montagem | Volume Lógico LVM | Tamanho Sugerido | Sistema Ficheiros | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| `/boot/efi` | Partição Direta | 1 GB | FAT32 | Arranque UEFI do sistema operativo. |
| `/boot` | Partição Direta | 2 GB | EXT4 | Ficheiros de Inicialização (Grub, Kernels). |
| `/` (Root) | `lv_root` | 50 GB | EXT4 | Sistema operativo Ubuntu, binários, bibliotecas e configuração (`/etc`). |
| `[SWAP]` | `lv_swap` | 4 GB | SWAP | Memória virtual (paginação). Recomendado semelhante a 50% ou 100% da sua RAM instalada. |
| `/var` | `lv_var` | 100 GB | EXT4 | Logs pesados, bases de dados *Prometheus* e o diretório vital de backups locais (`/var/backups/infra-aster`). |
| `/srv/samba`| `lv_samba` | 300 GB | EXT4 | O Servidor de ficheiros em si: Perfis dos colaboradores e "Pastas Públicas/Privadas". |
| *Espaço Livre*| Nenhum | Restante | N/A | Deixe sempre algum espaço de reserva (~40 GB) "não alocado" no Volume Group para permitir aumentar partições vitais a quente no futuro. |

### Cenário B: File Server Intensivo (Disco de 2TB)

Rede com grandes exigências de armazenamento de projetos pesados (Designers, Engenheiros, Gabinetes de Arquitetura).

| Ponto de Montagem | Volume Lógico LVM | Tamanho Sugerido | Sistema Ficheiros | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| `/boot/efi` | Partição Direta | 2 GB | FAT32 | Arranque UEFI do sistema. |
| `/boot` | Partição Direta | 2 GB | EXT4 | Ficheiros de Inicialização. |
| `/` (Root) | `lv_root` | 80 GB | EXT4 | Sistema operativo principal robustecido. |
| `[SWAP]` | `lv_swap` | 8 GB | SWAP | Memória virtual pesada. |
| `/var` | `lv_var` | 200 GB | EXT4 | Monitorização avançada (longa retenção de métricas) e backups diários com forte histórico de LDBs e Sysvol. |
| `/srv/samba`| `lv_samba` | 1500 GB | EXT4 ou XFS | Grande pãntano de dados corporativos e mapeamentos de Rede. |
| *Espaço Livre*| Nenhum | ~200 GB | N/A | Reserva gigantesca no Volume Group para a criação de *snapshots LVM* ou expansões de emergência na partição `lv_samba`. |

### Cenário C: Servidor Enterprise (Discos em RAID 1 + Múltiplos VGs)

Este é o cenário de excelência (Enterprise-Grade) para alta disponibilidade. Baseia-se na separação via *Software RAID* (`mdadm`) do Sistema Operativo e dos Dados do Samba, com isolamento microscópico de LVs críticos como `/var/log` e `/var/lib/samba`.

**Volume Group 1: `vg0` (Baseado no RAID `md0` de ~100GB)**
Focado exclusivamente na resiliência do Sistema, Bases de Dados LDB e Logs.

| Ponto de Montagem | Volume Lógico LVM | Tamanho Sugerido | Sistema Ficheiros | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| `/boot/efi` | Partição Direta | 1 GB | FAT32 | Arranque UEFI do sistema. |
| `/boot` | Partição Direta | 1 GB | EXT4 | Ficheiros de Inicialização. |
| `/` (Root) | `lv-Root` | 20 GB | EXT4 | Sistema operativo Ubuntu base. |
| `[SWAP]` | `lv-Swap` | 8 GB | SWAP | Memória virtual (paginação). |
| `/var` | `lv-Var` | 20 GB | EXT4 | Diretório variável principal (inclui `/var/backups`). |
| `/var/lib/samba`| `lv-Samba`| 40 GB | EXT4 | Isolamento extremo da Base de Dados LDB do Active Directory. |
| `/var/log` | `lv-Log` | 11 GB | EXT4 | Blindagem cirúrgica contra *Log Explosions* que poderiam travar o sistema. |

**Volume Group 2: `vg_Dados` (Baseado no RAID `md1` de ~500GB)**
Dedicado em exclusivo às partilhas de ficheiros pesados da empresa.

| Ponto de Montagem | Volume Lógico LVM | Tamanho Sugerido | Sistema Ficheiros | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| `/srv/samba`| `lv-Dados`| 499 GB | EXT4 | O Grande Repositório de Partilhas de rede e Perfis. |

> [!TIP]
> Dado que o `/var` base neste cenário dispõe de apenas 20GB, vigie de perto a retenção de grandes ficheiros na diretoria `/var/backups`. Se planeia reter Backups Locais durante várias semanas em vez das normais limpezas *off-site*, considere criar um `lv-Backup` no `vg_Dados` e montá-lo em `/var/backups/infra-aster` no futuro.

---

## 4. Guia Prático durante a Instalação (Ubuntu Server Instaler)

Quando iniciar a janela de formatação durante a instalação primária do Ubuntu (via pen USB):

1.  Chegue à secção **"Storage Configuration"** (Configuração de Armazenamento).
2.  Escolha obrigatoriamente a opção **"Custom storage layout"** (Disposição de armazenamento personalizada) em vez de deixar o CD usar e formatar todo o disco cegamente.
3.  Selecione o seu disco principal na lista. Crie primeiro uma `Add GPT partition` se o disco estiver virgem.
4.  No espaço "Free space" (Espaço livre), crie a partição EFI/boot: `Size: 1G` -> `Format: fat32` -> `Mount: /boot/efi`.
5.  Em "Free space", crie a partição Boot: `Size: 2G` -> `Format: ext4` -> `Mount: /boot`.
6.  No imenso **espaço livre restante da sua drive**, instrua a criação de um **"LVM Physical Volume" (PV)**.
7.  A seguir, crie um **"Volume Group (VG)"** (Grupo de Volumes, batizado como `vg_aster` se puder escolher o nome) anexando esse Physical Volume único ou até agregando vários discos rígidos em simultâneo!
8.  Por fim, dentro deste Grupo de Volumes Central, comece a fatiar visualmente os **"Logical Volumes (LVs)"** exatos e preciosos descritos nas tabelas de dimensionamento supra:
    *   Criar um LV chamado `lv_root` (Size: `50G`, Format: `ext4`, Montagem: `/`)
    *   Criar um LV chamado `lv_swap` (Size: `4G`, Format: `swap`)
    *   Criar um LV chamado `lv_var` (Size: `100G`, Format: `ext4`, Montagem: `/var`)
    *   Criar o pilar chamado `lv_samba` (Size: `300G`, Format: `ext4`, Montagem: `/srv/samba`)

Avance e confirme todas as ações no botão do fundo do ecrã e termine a instalação do Ubuntu de forma regular.

---

### Checagem da Estrutura (Pós-Instalação)

Muitos parabéns! Após a primeira inicialização da máquina, faça login no seu servidor como `root`, e confirme que é agora o Mestre absoluto da sua Arquitetura de Armazenamento executando o seguinte comando no ecrã preto:

```bash
lsblk
```

A saída deverá mostrar-lhe de forma espetacular uma árvore bem delineada em formato "Branches", exibindo perfeitamente as partições raiz e os recém-criados volumes elásticos sob as asas do Gestor LVM. 

Use o comando em baixo para atestar o espaço real formatado pronto a levar dados:
```bash
df -h
```

> [!TIP]
> **Expansão sem Reiniciar:** Quando os dias passarem e adquirir um novo disco rígido caríssimo focado apenas em estender o espaço da partilha da empresa (`/srv/samba`), meta o disco na máquina a quente, e utilize os 3 belos utilitários clássicos de expansão de blocos LVM numa só linha: `vgextend`, `lvextend`, e fechando luxuosamente com `resize2fs`. Concluiu este proeza épica com **ZERO de *downtime*** da sua base de dados ASTER ativa e dos seus serviços de rede!

Agora está pronto para prosseguir com a execução do principal [Script de Aprovisionamento](README.md).
