#!/bin/bash

# =========================================================================
# PERSISTENCE-STACK.SH
# =========================================================================
# Este script inicializa a infraestrutura básica do cluster Kubernetes:
#
# 1. Adiciona repositórios Helm necessários para todos os componentes
# 2. Atualiza a lista de charts disponíveis
# 3. Instala o Longhorn como solução de armazenamento persistente
# 4. Instala o PostgreSQL usando o chart Bitnami (opcional)
#
# Pré-requisitos:
# - Acesso ao cluster Kubernetes com contexto configurado
# - Ferramentas CLI já instaladas (kubectl, helm)
# - Arquivos de valores na pasta values
#
# IMPORTANTE:
# - A seção PostgreSQL é opcional caso você tenha um banco dedicado
# - Os taints são aplicados temporariamente para instalação do PostgreSQL
# - Aguarde 170 segundos para estabilização do Longhorn
# =========================================================================

set -e

# Cores
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${BLUE}💾 Configurando stack de persistência...${NC}"

# Adicionando repositórios Helm
echo -e "${PURPLE}📚 Adicionando repositórios Helm...${NC}"
helm repo add argo https://argoproj.github.io/argo-helm && \
helm repo add longhorn https://charts.longhorn.io && \
helm repo add metallb https://metallb.github.io/metallb && \
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest && \
helm repo add bitnami https://charts.bitnami.com/bitnami && \
helm repo add hashicorp https://helm.releases.hashicorp.com && \
helm repo add external-secrets https://charts.external-secrets.io && \
helm repo add kedacore https://kedacore.github.io/charts
echo

# Atualizando lista de charts
echo -e "${CYAN}🔄 Atualizando lista de charts...${NC}"
helm repo update
echo

# Instalando Longhorn
echo -e "${GREEN}💿 Instalando Longhorn...${NC}"
helm install longhorn longhorn/longhorn --values ../values/values-longhorn.yaml --namespace longhorn-system --create-namespace
echo

sleep 180

echo -e "${GREEN}✅ Stack de persistência configurado com sucesso!${NC}"
