#!/bin/bash
# LIMPEZA FORÇADA E REINSTALAÇÃO COM IPs DOS MANAGERS

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo -e "${BLUE}=== PARANDO TODOS OS PROCESSOS ===${NC}"

# 1. Parar RKE2
echo -e "${YELLOW}🛑 Parando serviços RKE2...${NC}"
sudo systemctl stop rke2-server
sudo systemctl stop rke2-agent

# 2. Verificar o que está usando a porta 6443
echo -e "${YELLOW}🧹 Executando script de desinstalação...${NC}"
/usr/local/bin/rke2-uninstall.sh

echo -e "${BLUE}Processos usando porta 6443:${NC}"
sudo lsof -i :6443
sudo netstat -tlnp | grep 6443

# 3. Matar TUDO relacionado a kubernetes/rke2
echo -e "${YELLOW}💀 Finalizando processos relacionados ao RKE2/Kubernetes...${NC}"
sudo pkill -9 -f kube-apiserver
sudo pkill -9 -f rke2
sudo pkill -9 -f kubelet
sudo pkill -9 -f containerd
sudo pkill -9 -f etcd

# 4. Verificar novamente
echo -e "${BLUE}Verificando se porta 6443 foi liberada:${NC}"
sudo lsof -i :6443 || echo -e "${GREEN}✅ Porta 6443 livre${NC}"

# 5. Limpeza completa
echo -e "${BLUE}=== REMOVENDO TODOS OS ARQUIVOS ===${NC}"
sudo rm -rf /etc/rancher
sudo rm -rf /var/lib/rancher
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/cni
sudo rm -rf /etc/cni
sudo rm -rf ~/.kube
sudo rm -rf /run/k3s
sudo rm -rf /run/flannel
sudo rm -rf /run/calico

# 6. Remover completamente o RKE2
echo -e "${YELLOW}🗑️ Removendo binários e serviços RKE2...${NC}"
sudo rm -f /usr/local/bin/rke2
sudo rm -f /usr/local/bin/rke2-*
sudo rm -rf /usr/local/share/rke2
sudo rm -f /etc/systemd/system/rke2-server.service
sudo rm -f /etc/systemd/system/rke2-agent.service
sudo rm -f /usr/local/lib/systemd/system/rke2-server.service
sudo rm -f /usr/local/lib/systemd/system/rke2-agent.service

# 7. Recarregar systemd
echo -e "${YELLOW}🔄 Recarregando systemd...${NC}"
sudo systemctl daemon-reload

# 8. Limpar iptables
echo -e "${YELLOW}🔥 Limpando regras do iptables...${NC}"
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X

sudo rm -rf /var/lib/longhorn

echo -e "${GREEN}✅ Limpeza finalizada com sucesso!${NC}"
