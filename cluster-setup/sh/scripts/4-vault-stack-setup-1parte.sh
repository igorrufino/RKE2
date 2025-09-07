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

# Cores
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${BLUE}🔐 Configurando o Vault...${NC}"

# Instalando Vault via Helm
echo -e "${PURPLE}📦 Instalando chart do Vault...${NC}"
helm install vault hashicorp/vault --namespace vault --values ../values/values-vault.yaml --version 0.29.1 --create-namespace
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

echo -e "${GREEN}✅ Vault configurado com sucesso!${NC}"
