#!/bin/bash

# =====================================================================
# SCRIPT DE INSTALAÇÃO DO KEDA E ARGOCD
# =====================================================================
# Este script instala e configura componentes de automação e CD:
#
# * Instala o KEDA (Kubernetes Event-driven Autoscaling)
#   para escalonamento baseado em eventos
# * Instala o ArgoCD (versão 7.8.5) com configurações personalizadas
# * Configura os segredos de repositório para o ArgoCD
# * Aplica a configuração inicial de aplicações no ArgoCD
# * Configura taints nos nós de controle
#
# IMPORTANTE:
# 1. O ArgoCD é instalado com valores personalizados do arquivo
#    values-argocd.yaml
# 2. Os segredos de repositório são configurados para permitir que
#    o ArgoCD acesse repositórios externos
# 3. As pausas são necessárias para garantir que cada componente
#    esteja completamente inicializado antes do próximo passo
# 4. O arquivo argocd-init.yaml define as aplicações iniciais
#    que serão gerenciadas pelo ArgoCD
# 5. Este script deve ser executado após a configuração do Vault
#    para garantir o acesso correto aos segredos
# =====================================================================

set -e

# =========================================================================
# CONFIGURAÇÕES - EDITE AQUI CONFORME SUA NECESSIDADE
# =========================================================================

# Nós para aplicar taints (separados por espaço)
TAINT_NODES=""


# Configurações do ArgoCD
ARGOCD_VERSION="8.2.5"
ARGOCD_NAMESPACE="argocd"
ARGOCD_RELEASE_NAME="argocd"
ARGOCD_VALUES_FILE="../values/values-argocd.yaml"

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

echo -e "${BLUE}🚀 Instalando ArgoCD...${NC}"

# Instalando ArgoCD
echo -e "${CYAN}🔄 Instalando ArgoCD v${ARGOCD_VERSION}...${NC}"
helm install $ARGOCD_RELEASE_NAME argo/argo-cd --version $ARGOCD_VERSION --values $ARGOCD_VALUES_FILE --namespace $ARGOCD_NAMESPACE --create-namespace
echo

# Aguardando instalação
echo -e "${YELLOW}⏳ Aguardando 40 segundos...${NC}"
sleep 40
echo

# Aplicando secrets de repositório
echo -e "${GREEN}🔐 Aplicando secrets de repositório...${NC}"
kubectl apply -f ../vault/repository-secrets/argocd-repository-secret-bitnami-helm.yaml
kubectl apply -f ../vault/repository-secrets/argocd-repository-secret-deployment.yaml
kubectl apply -f ../vault/repository-secrets/argocd-repository-secret-devops.yaml
kubectl apply -f ../vault/repository-secrets/argocd-repository-secret-helm.yaml
echo

# Aguardando secrets
echo -e "${YELLOW}⏳ Aguardando 50 segundos...${NC}"
sleep 50
echo

# # Aplicando configuração inicial
# echo -e "${BLUE}⚙️  Aplicando configuração inicial do ArgoCD...${NC}"
# kubectl apply -f ../values/argocd-init.yaml
# echo

echo -e "${GREEN}✅ KEDA e ArgoCD instalados com sucesso!${NC}"
