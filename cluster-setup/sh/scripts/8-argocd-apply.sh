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

# Cores
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Instalando KEDA e ArgoCD...${NC}"

# Instalando KEDA
echo -e "${PURPLE}📊 Instalando KEDA...${NC}"
helm install keda kedacore/keda --namespace keda --create-namespace
echo

# Instalando ArgoCD
echo -e "${CYAN}🔄 Instalando ArgoCD v7.8.5...${NC}"
helm install argocd argo/argo-cd --version 7.8.5 --values ../values/values-argocd.yaml --namespace argocd --create-namespace
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

# Aplicando configuração inicial
echo -e "${BLUE}⚙️  Aplicando configuração inicial do ArgoCD...${NC}"
kubectl apply -f ../values/argocd-init.yaml
echo

# Configurando taints nos nós
echo -e "${RED}🏷️  Aplicando taints nos nós manager...${NC}"
kubectl taint nodes sdayspk06h101 sdayspk06h102 sdayspk06h103 controlplane=true:NoSchedule-
echo

echo -e "${GREEN}✅ KEDA e ArgoCD instalados com sucesso!${NC}"
