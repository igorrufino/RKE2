#!/bin/bash

# =========================================================================
# SCRIPT DE CONVERTER SH PARA FORMATO UNIX E DAR PERMISSÃO DE EXECUÇÃO
# =========================================================================
# Este script automatiza a conversão de arquivos .sh para o formato Unix
#
# PRÉ-REQUISITOS OBRIGATÓRIOS:
# 1. Criar a estrutura de pastas:
#    sudo mkdir -p /opt/cluster-setup/scripts
#
# 2. Fazer upload dos scripts do cluster para:
#    /opt/cluster-setup/scripts/
#    (todos os arquivos .sh devem estar nesta pasta)
#
# 3. Executar este script como usuário com sudo
#
# IMPORTANTE:
# - Este script deve ser executado antes de qualquer outro script de instalação
# - Os arquivos em /opt/cluster-setup/scripts/ serão convertidos para formato Unix
# - Verifique os IPs nas variáveis IP1, IP2, IP3 antes de executar
#
# =========================================================================

set -e

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
NC='\033[0m'

echo -e "${BLUE}🔄 Convertendo scripts para formato Unix...${NC}"
if [ -d "/opt/cluster-scripts/scripts" ]; then
    cd /opt/cluster-scripts/scripts
    
    # Verificar se existem arquivos .sh
    if ls *.sh >/dev/null 2>&1; then
        echo -e "${YELLOW}📝 Arquivos encontrados:${NC}"
        ls -la *.sh
        echo
        
        # Converter todos os .sh
        echo -e "${YELLOW}🔄 Convertendo formato...${NC}"
        dos2unix *.sh 2>/dev/null || true
        
        # Dar permissão de execução para TODOS os arquivos .sh RECURSIVAMENTE
        echo -e "${YELLOW}🔧 Aplicando permissões de execução...${NC}"
        find /opt/cluster-scripts -type f -name "*.sh" -exec chmod +x {} \;
        
        echo -e "${CYAN}📋 Status final dos arquivos:${NC}"
        find /opt/cluster-scripts -type f -name "*.sh" -exec ls -la {} \;
        
        echo -e "${GREEN}✅ Scripts convertidos e com permissão de execução${NC}"
    else
        echo -e "${YELLOW}⚠️  Nenhum arquivo .sh encontrado${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Pasta /opt/cluster-scripts/scripts não encontrada${NC}"
fi
echo