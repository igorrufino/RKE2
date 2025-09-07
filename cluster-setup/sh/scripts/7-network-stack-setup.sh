#!/bin/bash

# =====================================================================
# SCRIPT DE CONFIGURAÇÃO DA REDE E SERVICE MESH
# =====================================================================
# Este script configura componentes essenciais de rede para o cluster:
#
# * Instala e configura o MetalLB como provedor de LoadBalancer
#   (necessário para ambientes que não têm LoadBalancer nativo)
# * Aplica as configurações de pool de IPs para o MetalLB
# * Instala o Istio como service mesh com perfil padrão
#
# IMPORTANTE:
# 1. O MetalLB precisa de um intervalo de IPs válido e disponível
#    na sua rede para funcionar corretamente
# 2. A pausa de 120 segundos é necessária para garantir que o MetalLB
#    esteja completamente inicializado antes da configuração
# 3. Verifique se não há conflitos de rede antes de executar
# 4. O Istio é instalado com perfil default, que pode exigir
#    recursos significativos do cluster
# =====================================================================

set -e

# Cores
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${BLUE}🌐 Configurando rede e service mesh...${NC}"

# Instalando MetalLB
echo -e "${PURPLE}📦 Instalando MetalLB...${NC}"
helm install metallb metallb/metallb --namespace metallb-system --create-namespace
echo

# Aguardando MetalLB
echo -e "${YELLOW}⏳ Aguardando 120 segundos para MetalLB...${NC}"
sleep 120
echo

# Aplicando configuração MetalLB
echo -e "${CYAN}⚙️  Aplicando configuração do MetalLB...${NC}"
kubectl apply -f ../values/values-metallb-ipaddres.yaml
echo

# Instalando Istio
echo -e "${GREEN}🕸️  Instalando Istio service mesh...${NC}"
istioctl install --set profile=default -y
echo

echo -e "${GREEN}✅ Rede e service mesh configurados com sucesso!${NC}"
