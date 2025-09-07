#!/bin/bash

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# Variáveis para os IPs que serão adicionados ao 'tls-san'
IP1=""
IP2=""
IP3=""
TOKEN=""


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

echo -e "${BLUE}=== DESABILITANDO APPARMOR E SELINUX ===${NC}"
sudo systemctl disable apparmor
sleep 2
sudo systemctl stop apparmor
sleep 2
setenforce 0 2>/dev/null || true
echo "SELINUX=disable" >> /etc/selinux/config
sleep 2
sudo zypper refresh -y
sleep 2
echo -e "${GREEN}✅ AppArmor e SELinux desabilitados${NC}\n"

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
sudo zypper refresh
echo
for pacote in "${pacotes[@]}"; do
    echo -e "${YELLOW}📦 Instalando $pacote...${NC}"
    sudo zypper install -y $pacote
done
echo -e "${GREEN}✅ Todos os pacotes foram instalados${NC}\n"

echo -e "${BLUE}=== HABILITANDO ISCSI ===${NC}"
sudo systemctl enable iscsid
sudo systemctl start iscsid
sleep 2
echo -e "${GREEN}✅ iSCSI habilitado${NC}\n"

echo -e "${BLUE}=== INSTALANDO RKE2 ===${NC}"
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
echo -e "${GREEN}✅ RKE2 instalado${NC}\n"

echo -e "${BLUE}=== CRIANDO CONFIGURAÇÃO RKE2 ===${NC}"
sudo mkdir -p /etc/rancher/rke2
sudo tee /etc/rancher/rke2/config.yaml > /dev/null << EOF
server: https://$IP1:9345
token: $TOKEN
tls-san:
  - $IP1
  - $IP2
  - $IP3
etcd-disable-snapshots: true
etcd-snapshot-schedule-cron: "0 0 0 0 0"
EOF
echo -e "${GREEN}✅ Configuração criada${NC}\n"

echo -e "${BLUE}=== INICIANDO RKE2 Agent===${NC}"
sudo systemctl enable rke2-agent.service
sudo systemctl start rke2-agent.service
echo -e "${GREEN}✅ RKE2 Agent iniciado${NC}\n"

echo -e "${BLUE}=== AGUARDANDO INICIALIZAÇÃO ===${NC}\n"

echo -e "${CYAN}📝 Comandos úteis:${NC}"
echo -e "${CYAN}  - Status: sudo systemctl status rke2-agent.service${NC}"
echo -e "${CYAN}  - Logs: sudo journalctl -u rke2-agent.service -f${NC}"
echo -e "${GREEN}🎉 Instalação concluída!${NC}"