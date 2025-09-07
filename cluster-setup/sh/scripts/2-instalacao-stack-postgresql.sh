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


# Configurando taints para PostgreSQL
echo -e "${RED}🏷️  Aplicando taints temporários...${NC}"
kubectl taint nodes srv-k8s-dev-002 srv-k8s-dev-003 srv-k8s-dev-004 controlplane=true:NoSchedule
echo

# Instalando PostgreSQL
echo -e "${BLUE}🗄️  Instalando PostgreSQL...${NC}"
helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.4.9 --namespace default --values ../values/values-postgresql.yaml
echo

# Aguardando PostgreSQL
echo -e "${YELLOW}⏳ Aguardando 10 segundos...${NC}"
sleep 10
echo

# Removendo taints
echo -e "${GREEN}🏷️  Removendo taints temporários...${NC}"
kubectl taint nodes srv-k8s-dev-002 srv-k8s-dev-003 srv-k8s-dev-004 controlplane=true:NoSchedule-
echo

echo -e "${GREEN}✅ Stack de persistência configurado com sucesso!${NC}"
