#!/bin/bash

# =========================================================================
# SCRIPT DE INSTALAÇÃO RKE2 - PRIMEIRO NÓ (CONTROL PLANE)
# =========================================================================
# Este script automatiza a instalação completa do RKE2 como control plane
#
# PRÉ-REQUISITOS OBRIGATÓRIOS:
# 1. Criar a estrutura de pastas:
#    sudo mkdir -p /opt/cluster-setup/scripts
#
# 2. Fazer upload dos scripts do cluster para:
#    /opt/cluster-setup/scripts/
#    (todos os arquivos .sh devem estar nesta pasta)
#
# 3. Executar este script como usuário com sudo
#
# IMPORTANTE:
# - Este script deve ser executado APENAS no primeiro nó (control plane)
# - Este script instala a manager node do RKE2, precisa adicionar os ips
# - Os arquivos em /opt/cluster-setup/scripts/ serão convertidos para formato Unix
# - Verifique os IPs nas variáveis IP1, IP2, IP3 antes de executar
# - O script instala: kubectl, helm, istioctl, RKE2 e dependências
#
# APÓS A EXECUÇÃO:
# - Use o token gerado para adicionar outros nós ao cluster
# - Configure kubectl nos outros servidores copiando ~/.kube/config
# =========================================================================

set -e

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
NC='\033[0m'

# Variáveis para os IPs que serão adicionados ao 'tls-san'
IP1=""
IP2=""
IP3=""

# Ferramentas e suas versões
declare -A tools=(
    ["kubectl"]="1.31.0"
    ["helm"]="latest"
    ["istioctl"]="1.23.2"
)

echo -e "${BLUE}=== DESABILITANDO FIREWALL ===${NC}"
sudo systemctl stop firewalld
sleep 2
sudo systemctl disable firewalld
sleep 2
echo -e "${GREEN}✅ Firewall desabilitado${NC}\n"

echo -e "${BLUE}=== ATUALIZANDO SISTEMA ===${NC}"
sudo zypper update -y
sleep 10
echo -e "${GREEN}✅ Sistema atualizado${NC}\n"

echo -e "${BLUE}=== DESABILITANDO APPARMOR  ===${NC}"
sudo systemctl disable apparmor
sleep 2
sudo systemctl stop apparmor
sleep 2
sudo zypper refresh -y
sleep 2
echo -e "${GREEN}✅ AppArmor desabilitado${NC}\n"

echo -e "${BLUE}=== DESATIVANDO SWAP ===${NC}"

# Desativa swap temporariamente
sudo swapoff -a
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}🔄 Swap desativado temporariamente${NC}"
else
    echo -e "${RED}❌ Erro ao desativar swap temporariamente${NC}"
fi

# Remove entradas de swap do /etc/fstab para desativação permanente
# Essa expressão só comenta linhas que contenham "swap" como tipo (coluna 3) e não já comentadas
sudo sed -i.bak -r '/^[^#].*\s+swap\s+/ s/^/#/' /etc/fstab
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}🔄 Entradas de swap comentadas no /etc/fstab (backup salvo como /etc/fstab.bak)${NC}"
else
    echo -e "${RED}❌ Erro ao modificar /etc/fstab${NC}"
fi

# Verifica se o swap está desativado corretamente
swap_total=$(free | awk '/^Swap:/ {print $2}')
if [ "$swap_total" -eq 0 ]; then
    echo -e "${GREEN}✅ Swap desativado com sucesso${NC}"
else
    echo -e "${YELLOW}⚠️  Swap ainda está ativo (${swap_total} KB) - pode ser necessário reiniciar${NC}"
fi

echo

echo -e "${BLUE}=== CONFIGURANDO HISTÓRICO DO BASH ===${NC}"
BASH_CONFIG_FILE="$HOME/.bashrc"
if grep -q "HISTTIMEFORMAT" "$BASH_CONFIG_FILE"; then
    echo -e "${GREEN}✅ HISTTIMEFORMAT já está configurado${NC}"
else
    echo 'export HISTTIMEFORMAT="%F %T "' >> "$BASH_CONFIG_FILE"
    echo -e "${GREEN}✅ HISTTIMEFORMAT configurado${NC}"
fi
source "$BASH_CONFIG_FILE"
echo

echo -e "${BLUE}=== INSTALANDO PACOTES NECESSÁRIOS ===${NC}"
pacotes=("vim" "psmisc" "telnet" "unzip" "net-tools" "htop" "dos2unix" "lsof" "sshfs" "open-iscsi")

# Fazer refresh APENAS uma vez no início (importante para VM nova)
echo -e "${YELLOW}🔄 Atualizando repositórios (única vez)...${NC}"
sudo zypper --non-interactive refresh

# Verificação rápida com rpm
echo -e "${YELLOW}📦 Verificando pacotes...${NC}"
missing=()
installed=()
for pkg in "${pacotes[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        installed+=("$pkg")
    else
        missing+=("$pkg")
    fi
done

# Mostrar status
[ ${#installed[@]} -gt 0 ] && echo -e "${GREEN}✅ Já instalados: ${installed[@]}${NC}"

if [ ${#missing[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Todos os pacotes já estão instalados${NC}\n"
else
    echo -e "${YELLOW}📦 Instalando: ${missing[@]}${NC}"
    sudo zypper --non-interactive install "${missing[@]}"
    echo -e "${GREEN}✅ Pacotes instalados com sucesso${NC}\n"
fi

# Converter arquivos para formato Unix
echo -e "${BLUE}🔄 Convertendo scripts para formato Unix...${NC}"
if [ -d "/opt/cluster-scripts/scripts" ]; then
    cd /opt/cluster-scripts/scripts
    
    # Verificar se existem arquivos .sh
    if ls *.sh >/dev/null 2>&1; then
        echo -e "${YELLOW}📝 Arquivos encontrados:${NC}"
        ls -la *.sh
        echo
        
        # Converter todos os .sh
        echo -e "${YELLOW}🔄 Convertendo formato...${NC}"
        dos2unix *.sh 2>/dev/null || true
        
        # Dar permissão de execução para TODOS os arquivos .sh RECURSIVAMENTE
        echo -e "${YELLOW}🔧 Aplicando permissões de execução...${NC}"
        find /opt/cluster-scripts -type f -name "*.sh" -exec chmod +x {} \;
        
        echo -e "${CYAN}📋 Status final dos arquivos:${NC}"
        find /opt/cluster-scripts -type f -name "*.sh" -exec ls -la {} \;
        
        echo -e "${GREEN}✅ Scripts convertidos e com permissão de execução${NC}"
    else
        echo -e "${YELLOW}⚠️  Nenhum arquivo .sh encontrado${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Pasta /opt/cluster-scripts/scripts não encontrada${NC}"
fi
echo

echo -e "${BLUE}=== INSTALANDO FERRAMENTAS KUBERNETES ===${NC}"

# kubectl
if command -v kubectl >/dev/null 2>&1; then
    echo -e "${GREEN}✅ kubectl já instalado${NC}"
else
    echo -e "${YELLOW}📦 Instalando kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/v${tools[kubectl]}/bin/linux/amd64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/
    echo -e "${GREEN}✅ kubectl instalado${NC}"
fi

# helm
if command -v helm >/dev/null 2>&1; then
    echo -e "${GREEN}✅ helm já instalado${NC}"
else
    echo -e "${YELLOW}📦 Instalando helm...${NC}"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo -e "${GREEN}✅ helm instalado${NC}"
fi

# istioctl
if command -v istioctl >/dev/null 2>&1; then
    echo -e "${GREEN}✅ istioctl já instalado${NC}"
else
    echo -e "${YELLOW}📦 Instalando istioctl v${tools[istioctl]}...${NC}"
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${tools[istioctl]} sh -
    sudo mv istio-${tools[istioctl]}/bin/istioctl /usr/local/bin/
    rm -rf istio-${tools[istioctl]}
    echo -e "${GREEN}✅ istioctl instalado${NC}"
fi

# Verificar versões instaladas
echo -e "${CYAN}\n📋 Versões instaladas:${NC}"
kubectl version --client --short 2>/dev/null | head -1 || echo "kubectl: instalado"
helm version --short 2>/dev/null || echo "helm: instalado"
istioctl version --remote=false 2>/dev/null | head -1 || echo "istioctl: instalado"
echo

echo -e "${BLUE}=== HABILITANDO ISCSI ===${NC}"
sudo systemctl enable iscsid
sudo systemctl start iscsid
sleep 2
echo -e "${GREEN}✅ iSCSI habilitado${NC}\n"

echo -e "${BLUE}=== INSTALANDO RKE2 ===${NC}"
curl -sfL https://get.rke2.io | sudo sh -
echo -e "${GREEN}✅ RKE2 instalado${NC}\n"

echo -e "${BLUE}=== CRIANDO CONFIGURAÇÃO RKE2 ===${NC}"
sudo mkdir -p /etc/rancher/rke2
sudo tee /etc/rancher/rke2/config.yaml > /dev/null << EOF
tls-san:
  - $IP1
  - $IP2
  - $IP3

# ====== COMPONENTES DESABILITADOS ======
disable-cloud-controller: true
disable:
  - rke2-ingress-nginx
  - rke2-snapshot-controller
  - rke2-snapshot-validation-webhook

# ====== ETCD OTIMIZADO PARA PERFORMANCE ======
etcd-disable-snapshots: true
etcd-arg:
  - "auto-compaction-retention=1h"     
  - "auto-compaction-mode=periodic"
# ====== API SERVER PARA ALTA PERFORMANCE ======
kube-apiserver-arg:
  - "audit-log-maxage=7"
  - "audit-log-maxbackup=3"
  - "audit-log-maxsize=50"
  - "enable-priority-and-fairness=true" # Gerenciamento inteligente de filas

# ====== KUBELET OTIMIZADO ======
kubelet-arg:
  - "image-gc-high-threshold=85"
  - "image-gc-low-threshold=80"
EOF
echo -e "${GREEN}✅ Configuração criada${NC}\n"

echo -e "${BLUE}=== INICIANDO RKE2 SERVER ===${NC}"
sudo systemctl enable rke2-server
sudo systemctl start rke2-server
echo -e "${GREEN}✅ RKE2 server iniciado${NC}\n"

echo -e "${BLUE}=== AGUARDANDO INICIALIZAÇÃO ===${NC}"
echo -n "Aguardando token"
for i in {1..12}; do
    echo -n "."
    sleep 10
    if [ -f /var/lib/rancher/rke2/server/node-token ]; then
        echo
        echo -e "${GREEN}✅ Token gerado!${NC}"
        break
    fi
done
echo

echo -e "${BLUE}=== CONFIGURANDO PATH ===${NC}"
export PATH=$PATH:/var/lib/rancher/rke2/bin
echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
echo -e "${GREEN}✅ PATH configurado${NC}\n"

echo -e "${BLUE}=== CONFIGURANDO KUBECONFIG ===${NC}"
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
    mkdir -p ~/.kube
    sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config
    sed -i "s/127.0.0.1:6443/$IP1:6443/g" ~/.kube/config
    echo -e "${GREEN}✅ Kubeconfig configurado em ~/.kube/config${NC}"
    echo -e "${GREEN}✅ API server configurado para: $IP1:6443${NC}"
else
    echo -e "${YELLOW}❌ Arquivo rke2.yaml ainda não foi criado${NC}"
fi
echo

echo -e "${BLUE}=== INFORMAÇÕES DO CLUSTER ===${NC}\n"
echo -e "${CYAN}🔑 Token para outros nós:${NC}"
sudo cat /var/lib/rancher/rke2/server/node-token 2>/dev/null || echo "Token ainda não disponível"
echo
echo -e "${CYAN}📝 Comandos úteis:${NC}"
echo -e "${CYAN}  - Status: sudo systemctl status rke2-server${NC}"
echo -e "${CYAN}  - Logs: sudo journalctl -u rke2-server -f${NC}"
echo -e "${CYAN}  - Nodes: kubectl get nodes${NC}\n"

# 🔒 Desabilitar swap se existir
if systemctl list-units --type=swap | grep -q "dev-sda3.swap"; then
  echo -e "${BLUE}🔒 Desabilitando swap dev-sda3.swap...${NC}"
  sudo systemctl stop dev-sda3.swap
  sudo systemctl disable dev-sda3.swap
  sudo systemctl mask dev-sda3.swap
  echo -e "${GREEN}✅ Swap dev-sda3.swap desabilitada com sucesso${NC}\n"
else
  echo -e "${YELLOW}⚠️ Swap dev-sda3.swap não encontrada. Pulando etapa.${NC}\n"
fi

echo -e "${GREEN}🎉 Instalação concluída!${NC}"