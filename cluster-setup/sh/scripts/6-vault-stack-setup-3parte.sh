#!/bin/bash

# =====================================================================
# SCRIPT DE CONFIGURAÇÃO DO EXTERNAL SECRETS
# =====================================================================
# Este script instala e configura o External Secrets Operator:
#
# * Instala o External Secrets via Helm
# * Configura ServiceAccount e permissões RBAC
# * Habilita autenticação Kubernetes no Vault
# * Cria role para integração Vault-Kubernetes
# * Configura backend do External Secrets com token do Vault
#
# IMPORTANTE:
# 1. Execute após configurar o Vault e suas políticas
# 2. O arquivo vault-token-policy.txt deve existir
# 3. Os arquivos YAML de configuração devem estar nos paths corretos
# 4. Aguarde a estabilização entre as etapas
# 5. ALTERAÇÃO: Configuração resiliente a rotação de certificados RKE2
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

echo -e "${BLUE}🔑 Configurando External Secrets...${NC}"

# Instalando External Secrets
echo -e "${PURPLE}📦 Instalando chart do External-Secrets...${NC}"
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --set installCRDs=true
echo

# Aguardando instalação
echo -e "${YELLOW}⏳ Aguardando 50 segundos...${NC}"
sleep 50
echo

# Aplicando configurações de ServiceAccount
echo -e "${CYAN}🔐 Configurando ServiceAccount...${NC}"
kubectl apply -f ../vault/serviceacount/external-secrets-token.yaml
kubectl apply -f ../vault/serviceacount/external-secrets-binding.yaml
kubectl apply -f ../vault/serviceacount/external-secrets-role.yaml
kubectl create clusterrolebinding external-secrets-auth-delegator --clusterrole=system:auth-delegator --serviceaccount=external-secrets:external-secrets
echo

# Habilitando auth method Kubernetes
echo -e "${RED}🔗 Habilitando auth method Kubernetes...${NC}"
kubectl exec -n vault vault-0 -- vault auth enable kubernetes
echo

# Configurando auth method Kubernetes (resiliente a rotação de certificados)
echo -e "${GREEN}⚙️  Configurando auth method Kubernetes...${NC}"
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc" token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token issuer="https://kubernetes.default.svc.cluster.local" disable_iss_validation="true" disable_local_ca_jwt="false"
echo

# Criando role para Vault
echo -e "${PURPLE}👤 Criando role para o Vault...${NC}"
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/app-role bound_service_account_names=external-secrets bound_service_account_namespaces=external-secrets policies=vault-policy ttl=0 max_ttl=0 period=768h
echo

# Aguardando configuração
echo -e "${YELLOW}⏳ Aguardando 60 segundos...${NC}"
sleep 60
echo

# Extraindo token e configurando backend
echo -e "${CYAN}🎫 Configurando backend External-Secrets...${NC}"
POLICY_TOKEN=$(grep "token" vault-token-policy.txt | grep "hvs." | awk '{print $2}')
kubectl create secret generic vault-policy-token -n external-secrets --from-literal=token=$POLICY_TOKEN
kubectl apply -f ../vault/backend-external-secrets/vault-backend-external-secrets.yaml
echo

echo -e "${GREEN}✅ External Secrets configurado com sucesso!${NC}"
echo -e "${YELLOW}💡 Configuração resiliente a rotação de certificados RKE2 aplicada${NC}"
