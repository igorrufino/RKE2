#!/bin/bash

# =====================================================================
# SCRIPT DE DESBLOQUEIO DO VAULT APÓS REINICIALIZAÇÃO
# =====================================================================
# Este script desbloqueia (unseal) o Vault após uma reinicialização:
#
# * Extrai as chaves de desbloqueio e o Root Token do arquivo vault-init.txt
# * Executa a operação de desbloqueio do Vault com as 3 chaves necessárias
# * Realiza login no Vault usando o Root Token
#
# IMPORTANTE:
# 1. Este script deve ser executado quando o Vault estiver selado
#    após uma reinicialização do cluster ou do pod do Vault
# 2. O arquivo vault-init.txt precisa existir e conter as chaves
#    e o token gerados durante a inicialização original
# 3. As chaves e tokens são altamente sensíveis - mantenha o arquivo
#    vault-init.txt em local seguro
# 4. A pausa de 20 segundos permite que o Vault se estabilize após
#    o desbloqueio
# 5. Qualquer falha na extração das chaves ou tokens interromperá o script
# =====================================================================

echo "Desbloqueando o vault..."

# Extraindo as Unseal Keys e o Root Token do arquivo vault-init.txt
UNSEAL_KEY_1=$(grep "Unseal Key 1:" vault-init.txt | awk '{print $4}')
UNSEAL_KEY_2=$(grep "Unseal Key 2:" vault-init.txt | awk '{print $4}')
UNSEAL_KEY_3=$(grep "Unseal Key 3:" vault-init.txt | awk '{print $4}')
ROOT_TOKEN=$(grep "Initial Root Token:" vault-init.txt | awk '{print $4}')

# Verificação se os tokens foram extraídos corretamente
if [ -z "$ROOT_TOKEN" ]; then
    echo "Erro: ROOT_TOKEN não foi extraído corretamente."
    exit 1
fi

# Usando as Unseal Keys para deslacrar o Vault
echo "Desbloquando o Vault..."
../cli-tools/kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
../cli-tools/kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
../cli-tools/kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3

# Pausa para garantir a instalação correta do vault
echo "Pausando o script por 20 segundos..."
sleep 20
echo

# Logando no Vault usando o Root Token
echo "Logando no Vault..."
../cli-tools/kubectl exec -n vault vault-0 -- vault login -no-print $ROOT_TOKEN
if [ $? -ne 0 ]; then
    echo "Erro ao logar no Vault."
    exit 1
fi

echo "Script concluído com sucesso!" 