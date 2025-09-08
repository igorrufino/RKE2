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

# =========================================================================
# CONFIGURAÇÕES - EDITE AQUI CONFORME SUA NECESSIDADE
# =========================================================================

# Nós para aplicar taints (separados por espaço)
TAINT_NODES=""

# Configurações do PostgreSQL
POSTGRES_VERSION="16.4.9"
POSTGRES_NAMESPACE="default"
POSTGRES_RELEASE_NAME="postgres"
POSTGRES_VALUES_FILE="../values/values-postgresql.yaml"

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
RED='\033[1;31m'
NC='\033[0m'

# Configurando taints
echo -e "${RED}🏷️  Aplicando taints temporários...${NC}"
kubectl taint nodes $TAINT_NODES $TAINT_KEY=$TAINT_VALUE:$TAINT_EFFECT
echo

# Instalando PostgreSQL
echo -e "${BLUE}🗄️  Instalando PostgreSQL...${NC}"
helm install $POSTGRES_RELEASE_NAME oci://registry-1.docker.io/bitnamicharts/postgresql \
    --version $POSTGRES_VERSION \
    --namespace $POSTGRES_NAMESPACE \
    --values $POSTGRES_VALUES_FILE
echo

# Aguardando PostgreSQL
echo -e "${YELLOW}⏳ Aguardando $WAIT_TIME segundos...${NC}"
sleep $WAIT_TIME
echo

# Removendo taints
echo -e "${GREEN}🏷️  Removendo taints temporários...${NC}"
kubectl taint nodes $TAINT_NODES $TAINT_KEY=$TAINT_VALUE:$TAINT_EFFECT-
echo

echo -e "${GREEN}✅ Stack de PostgreSQL configurado com sucesso!${NC}"
echo
echo -e "${CYAN}📋 Configuração aplicada:${NC}"
echo -e "PostgreSQL: $POSTGRES_RELEASE_NAME v$POSTGRES_VERSION"
echo -e "Namespace: $POSTGRES_NAMESPACE"