#!/bin/bash

# =====================================================================
# SCRIPT DE CONFIGURAÇÃO DO VAULT
# =====================================================================
# Este script realiza a instalação e configuração inicial do Vault:
#
# * Instala o Vault via Helm chart (versão 0.29.1)
# * Inicializa o Vault com 5 chaves (threshold de 3)
# * Desbloqueia (unseal) o Vault automaticamente
# * Faz login inicial com o Root Token
#
# IMPORTANTE:
# 1. Verifique se o PostgreSQL está rodando antes de executar
# 2. As credenciais e tokens sensíveis são salvos em vault-init.txt
# 3. Proteja o arquivo vault-init.txt após a execução
# 4. Os tempos de espera são importantes para estabilização
# =====================================================================

set -e

# =========================================================================
# CONFIGURAÇÕES - EDITE AQUI CONFORME SUA NECESSIDADE
# =========================================================================


# Configurações do Vault
VAULT_VERSION="0.30.1"
VAULT_NAMESPACE="vault"
VAULT_RELEASE_NAME="vault"
VAULT_VALUES_FILE="../values/values-vault.yaml"

# Nós para aplicar taints (separados por espaço)
TAINT_NODES=""


# Configurações do taint
TAINT_KEY="controlplane"
TAINT_VALUE="true"
TAINT_EFFECT="NoSchedule"

# Tempo de espera após instalação (segundos)
WAIT_TIME="10"

# =========================================================================

# Cores
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Configurando taints
echo -e "${RED}🏷️  Aplicando taints temporários...${NC}"
kubectl taint nodes $TAINT_NODES $TAINT_KEY=$TAINT_VALUE:$TAINT_EFFECT
echo

echo -e "${BLUE}🔐 Configurando o Vault...${NC}"

# Instalando Vault via Helm
echo -e "${PURPLE}📦 Instalando chart do Vault...${NC}"
helm install $VAULT_RELEASE_NAME hashicorp/vault --namespace $VAULT_NAMESPACE --values $VAULT_VALUES_FILE --version $VAULT_VERSION --create-namespace
echo

# Aguardando instalação
echo -e "${YELLOW}⏳ Aguardando 90 segundos para instalação...${NC}"
sleep 90
echo

# Inicializando Vault
echo -e "${CYAN}🚀 Inicializando server do Vault...${NC}"
kubectl exec -n vault vault-0 -- vault operator init -key-shares=5 -key-threshold=3 > vault-init.txt
echo

# Aguardando inicialização
echo -e "${YELLOW}⏳ Aguardando 50 segundos para inicialização...${NC}"
sleep 50
echo

# Extraindo chaves e token
echo -e "${BLUE}🔑 Extraindo chaves do arquivo...${NC}"
UNSEAL_KEY_1=$(grep "Unseal Key 1:" vault-init.txt | awk '{print $4}')
UNSEAL_KEY_2=$(grep "Unseal Key 2:" vault-init.txt | awk '{print $4}')
UNSEAL_KEY_3=$(grep "Unseal Key 3:" vault-init.txt | awk '{print $4}')
ROOT_TOKEN=$(grep "Initial Root Token:" vault-init.txt | awk '{print $4}')
echo

# Desbloqueando Vault
echo -e "${CYAN}🔓 Desbloqueando o Vault...${NC}"
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3
echo

# Aguardando desbloqueio
echo -e "${YELLOW}⏳ Aguardando 20 segundos...${NC}"
sleep 20
echo

# Login no Vault
echo -e "${PURPLE}🔐 Fazendo login no Vault...${NC}"
kubectl exec -n vault vault-0 -- vault login -no-print $ROOT_TOKEN
echo

# Removendo taints
echo -e "${GREEN}🏷️  Removendo taints temporários...${NC}"
kubectl taint nodes $TAINT_NODES $TAINT_KEY=$TAINT_VALUE:$TAINT_EFFECT-
echo

echo -e "${GREEN}✅ Vault configurado com sucesso!${NC}"
echo
echo -e "${CYAN}📋 Configuração aplicada:${NC}"
echo -e "   Vault: $VAULT_RELEASE_NAME v$VAULT_VERSION"
