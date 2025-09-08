#!/bin/bash

# =========================================================================
# 4-CONFIGURACAO-SCRIPTS-SQL.SH
# =========================================================================
# Script para configurar banco de dados PostgreSQL para o Vault
# Funciona tanto para PostgreSQL interno (cluster) quanto externo
#
# Variáveis de ambiente necessárias:
# - PG_HOST: Host do PostgreSQL (ex: postgres-postgresql ou IP externo)
# - PG_PORT: Porta do PostgreSQL (padrão: 5432)
# - PG_USER: Usuário admin do PostgreSQL (padrão: postgres)
# - PG_PASSWORD: Senha do usuário admin
# - PG_DATABASE: Banco de dados inicial (padrão: postgres)
# - USE_K8S_SECRET: true se usar secret do k8s, false se usar env vars
# - K8S_SECRET_NAME: nome do secret (padrão: postgres-postgresql)
# - VAULT_USER: usuário que será criado para o vault (padrão: vault_user)
# - VAULT_PASSWORD: senha do usuário vault (padrão: cJAHRHqezuxCMMW)
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

# =========================================================================
# CONFIGURAÇÕES - EDITE AQUI CONFORME SUA NECESSIDADE
# =========================================================================

# Para PostgreSQL INTERNO (cluster):
PG_HOST="postgres-postgresql"
PG_PORT="5432"
PG_USER="postgres"
PG_DATABASE="postgres"
USE_K8S_SECRET="true"
K8S_SECRET_NAME="postgres-postgresql"

# Para PostgreSQL EXTERNO, altere os valores acima:
# PG_HOST="192.168.1.100"
# PG_PASSWORD="sua_senha"
# PG_USER="postgres"
# PG_DATABASE="postgres"
# USE_K8S_SECRET="false"

VAULT_USER="vault_user"
VAULT_PASSWORD="password"

# Função para obter senha do PostgreSQL
get_postgres_password() {
    if [ "$USE_K8S_SECRET" = "true" ]; then
        echo -e "${CYAN}🔑 Obtendo senha do secret Kubernetes...${NC}"
        PG_PASSWORD=$(kubectl get secret "$K8S_SECRET_NAME" -o jsonpath="{.data.postgres-password}" | base64 --decode)
        if [ -z "$PG_PASSWORD" ]; then
            echo -e "${RED}❌ Erro: Não foi possível obter a senha do secret $K8S_SECRET_NAME${NC}"
            exit 1
        fi
    else
        if [ -z "$PG_PASSWORD" ]; then
            echo -e "${RED}❌ Erro: PG_PASSWORD não definida e USE_K8S_SECRET=false${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}✅ Senha obtida com sucesso${NC}"
}

# Função para testar conectividade
test_connection() {
    echo -e "${YELLOW}🔌 Testando conectividade com PostgreSQL...${NC}"
    
    # Criar Job temporário para testar conexão
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-connection-test
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: postgres-client
        image: postgres:16
        env:
        - name: PGPASSWORD
          value: "$PG_PASSWORD"
        command:
        - /bin/bash
        - -c
        - |
          for i in {1..30}; do
            if pg_isready -h $PG_HOST -p $PG_PORT -U $PG_USER >/dev/null 2>&1; then
              echo "PostgreSQL está pronto!"
              psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT version();" >/dev/null 2>&1
              echo "Conexão testada com sucesso!"
              exit 0
            fi
            echo "Tentativa \$i/30... aguardando 10 segundos"
            sleep 10
          done
          echo "Falha ao conectar no PostgreSQL"
          exit 1
        env:
        - name: PG_HOST
          value: "$PG_HOST"
        - name: PG_PORT
          value: "$PG_PORT"
        - name: PG_USER
          value: "$PG_USER"
        - name: PG_DATABASE
          value: "$PG_DATABASE"
EOF

    # Aguardar conclusão do teste
    kubectl wait --for=condition=complete --timeout=300s job/postgres-connection-test
    
    if kubectl get job postgres-connection-test -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        echo -e "${GREEN}✅ Conectividade confirmada!${NC}"
        kubectl delete job postgres-connection-test
    else
        echo -e "${RED}❌ Falha na conectividade${NC}"
        kubectl logs job/postgres-connection-test
        kubectl delete job postgres-connection-test
        exit 1
    fi
}

# Função para executar configuração SQL
execute_vault_configuration() {
    echo -e "${CYAN}🗄️ Configurando banco de dados para o Vault...${NC}"
    
    # Verificar se arquivo SQL existe
    if [ ! -f "03-init-vault-db.sql" ]; then
        echo -e "${RED}❌ Arquivo 03-init-vault-db.sql não encontrado!${NC}"
        exit 1
    fi
    
    # Criar ConfigMap com o script SQL
    kubectl create configmap vault-init-sql --from-file=03-init-vault-db.sql
    
    # Executar o script SQL via Job
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: vault-db-config
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: postgres-client
        image: postgres:16
        env:
        - name: PGPASSWORD
          value: "$PG_PASSWORD"
        - name: PG_HOST
          value: "$PG_HOST"
        - name: PG_PORT
          value: "$PG_PORT"
        - name: PG_USER
          value: "$PG_USER"
        - name: PG_DATABASE
          value: "$PG_DATABASE"
        - name: VAULT_USER
          value: "$VAULT_USER"
        - name: VAULT_PASSWORD
          value: "$VAULT_PASSWORD"
        command:
        - /bin/bash
        - -c
        - |
          echo "Executando configuração do Vault..."
          
          # Substituir variáveis no script SQL
          sed -e "s/{{VAULT_USER}}/$VAULT_USER/g" \
              -e "s/{{VAULT_PASSWORD}}/$VAULT_PASSWORD/g" \
              /sql/03-init-vault-db.sql > /tmp/processed-init.sql
              
          # Executar script SQL
          psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -f /tmp/processed-init.sql
          
          echo "Configuração concluída!"
        volumeMounts:
        - name: sql-script
          mountPath: /sql
      volumes:
      - name: sql-script
        configMap:
          name: vault-init-sql
EOF

    # Aguardar conclusão do Job
    echo -e "${YELLOW}⏳ Executando configuração do Vault...${NC}"
    kubectl wait --for=condition=complete --timeout=300s job/vault-db-config
    
    if kubectl get job vault-db-config -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
        echo -e "${GREEN}✅ Configuração do Vault concluída com sucesso!${NC}"
        
        # Mostrar logs para confirmação
        echo -e "${CYAN}📋 Logs da configuração:${NC}"
        kubectl logs job/vault-db-config
        
        # Limpar recursos temporários
        kubectl delete job vault-db-config
        kubectl delete configmap vault-init-sql
    else
        echo -e "${RED}❌ Falha na configuração do banco de dados${NC}"
        echo -e "${YELLOW}📋 Logs do erro:${NC}"
        kubectl logs job/vault-db-config
        
        # Limpar recursos mesmo em caso de erro
        kubectl delete job vault-db-config --ignore-not-found=true
        kubectl delete configmap vault-init-sql --ignore-not-found=true
        exit 1
    fi
}

# Script principal
echo -e "${PURPLE}🚀 Iniciando configuração do banco para o Vault...${NC}"
echo -e "${CYAN}📋 Configurações:${NC}"
echo -e "   Host: $PG_HOST"
echo -e "   Porta: $PG_PORT"
echo -e "   Usuário Admin: $PG_USER"
echo -e "   Banco Inicial: $PG_DATABASE"
echo -e "   Usar Secret K8s: $USE_K8S_SECRET"
echo -e "   Usuário Vault: $VAULT_USER"
echo

# Obter senha do PostgreSQL
get_postgres_password

# Testar conectividade
test_connection

# Executar configuração
execute_vault_configuration

echo -e "${GREEN}✅ Configuração completa!${NC}"
echo
echo -e "${CYAN}📋 Credenciais do Vault configuradas:${NC}"
echo -e "   Host: $PG_HOST:$PG_PORT"
echo -e "   Usuário: $VAULT_USER"
echo -e "   Senha: $VAULT_PASSWORD"
echo -e "   Banco: vault"