#!/bin/bash

# =====================================================================
# SCRIPT DE CONFIGURAÇÃO DE SECRETS E POLÍTICAS DO VAULT
# =====================================================================
# Este script configura os secrets engines e políticas do Vault:
#
# * Habilita secrets engines para diferentes aplicações
# * Configura repositórios do ArgoCD no Vault
# * Cria secrets para third-party (MongoDB, Redis, RabbitMQ)
# * Aplica políticas de segurança
# * Gera token com política específica
#
# IMPORTANTE:
# 1. Execute após o script de setup inicial do Vault
# 2. O arquivo vault-policy.hcl deve existir no caminho especificado
# 3. O token gerado é salvo em vault-token-policy.txt
# 4. Proteja os arquivos de token após execução
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

echo -e "${BLUE}🔐 Configurando secrets e políticas do Vault...${NC}"

# Habilitando secrets engines
echo -e "${PURPLE}📂 Habilitando secrets engines...${NC}"
kubectl exec -n vault vault-0 -- vault secrets enable -path=argocd kv
kubectl exec -n vault vault-0 -- vault secrets enable -path=third-party kv
kubectl exec -n vault vault-0 -- vault secrets enable -path=monitoring kv
kubectl exec -n vault vault-0 -- vault secrets enable -path=fast-trade kv
kubectl exec -n vault vault-0 -- vault secrets enable -path=iaas kv
kubectl exec -n vault vault-0 -- vault secrets enable -path=iam kv
echo

# Copiando arquivo de política
echo -e "${CYAN}📋 Copiando arquivo de política...${NC}"
kubectl cp ../vault/policys/vault-policy.hcl vault/vault-0:/tmp/vault-policy.hcl
echo

# Criando secrets para ArgoCD
echo -e "${YELLOW}🔗 Criando secrets repositórios ArgoCD...${NC}"
kubectl exec -n vault vault-0 -- vault kv put argocd/helm-repo name="cedro-helm" url="https://bitbucket.org/cedrolab/helm" type="git" project="default" username="default" password="default"
kubectl exec -n vault vault-0 -- vault kv put argocd/bitnami-helm-repo name="bitnami" url="https://charts.bitnami.com/bitnami" type="helm" project="default"
kubectl exec -n vault vault-0 -- vault kv put argocd/deployment-repo name="cedro-config" url="https://bitbucket.org/cedrolab/daycoval_deployment_configs" type="git" project="default" username="default" password="default"
kubectl exec -n vault vault-0 -- vault kv put argocd/devops-deploymen-repo url="https://bitbucket.org/cedrolab/devops_deployment_configs" type="git" username="default" password="default"
echo

# Criando secrets para Third-party
echo -e "${RED}🗄️  Criando secrets third-party...${NC}"
kubectl exec -n vault vault-0 -- vault kv put third-party/mongodb mongodb-passwords="valor" mongodb-root-password="valor"
kubectl exec -n vault vault-0 -- vault kv put third-party/redis-oms redis-password="valor"
kubectl exec -n vault vault-0 -- vault kv put third-party/rabbitmq rabbitmq-password="valor"
echo

# Criando políticas e roles
echo -e "${GREEN}🛡️  Criando políticas e roles...${NC}"
kubectl exec -n vault vault-0 -- vault policy write vault-policy /tmp/vault-policy.hcl
kubectl exec -n vault vault-0 -- vault token create -policy="vault-policy" -ttl=0 -renewable=true -period=768h > vault-token-policy.txt
echo

echo -e "${GREEN}✅ Configuração de secrets concluída com sucesso!${NC}"
