# Configuração do Vault com Kubernetes Authentication

## 1. Configuração Inicial

### 1.1 ConfigMap do Vault
```hcl
disable_mlock = true
ui = true

listener "tcp" {
  tls_disable = 1
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
}

storage "raft" {
  path = "/vault/data"
  node_id = "raft_node_1"
}

service_registration "kubernetes" {}

auth_enable "kubernetes" {
  type = "kubernetes"
  config = {
    kubernetes_host = "https://kubernetes.default.svc"
    kubernetes_ca_cert = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    token_reviewer_jwt = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    issuer = "kubernetes.default.svc"
    disable_iss_validation = "true"
    disable_local_ca_jwt = "true"
  }
}
```

### 1.2 Policy Configurada
```hcl
path "third-party/*" {
  capabilities = ["read", "list"]
}
path "argocd/*" {
  capabilities = ["read", "list"]
}
path "monitoring/*" {
  capabilities = ["read", "list"]
}
path "fast-trade/*" {
  capabilities = ["read", "list"]
}
path "iaas/*" {
  capabilities = ["read", "list"]
}
path "iam/*" {
  capabilities = ["read", "list"]
}
path "tridar/*" {
  capabilities = ["read", "list"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

## 2. Passos de Configuração

### 2.1 Habilitar Autenticação Kubernetes
```bash
kubectl exec -n vault vault-0 -- vault auth enable kubernetes
```

### 2.2 Configurar Auth Method
```bash
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
    issuer="kubernetes.default.svc" \
    disable_iss_validation="true" \
    disable_local_ca_jwt="true"
```

### 2.3 Criar Role
```bash
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/app-role \
    bound_service_account_names=* \
    bound_service_account_namespaces=* \
    policies=vault-policy \
    ttl=24h
```

### 2.4 ClusterSecretStore
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend-external
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: ""
      version: "v1"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "app-role"
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

## 3. Como Testar e Validar

### 3.1 Verificar Status da Autenticação
```bash
# Listar métodos de autenticação
kubectl exec -n vault vault-0 -- vault auth list

# Verificar configuração do Kubernetes
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/config

# Verificar role
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/app-role
```

### 3.2 Testar Token e Expiração
```bash
# Criar token de teste
kubectl create token external-secrets -n external-secrets

# Testar login com o token
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/login \
    role=app-role \
    jwt=[TOKEN_GERADO]

# Ver informações do token (incluindo TTL)
kubectl exec -n vault vault-0 -- vault token lookup
```

### 3.3 Testar ClusterSecretStore
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: default
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend-external
    kind: ClusterSecretStore
  target:
    name: test-secret
  data:
  - secretKey: test-key
    remoteRef:
      key: third-party/test-secret
```

### 3.4 Verificar Logs
```bash
# Logs do Vault
kubectl logs vault-0 -n vault

# Logs do External Secrets Operator
kubectl logs -l app.kubernetes.io/name=external-secrets -n external-secrets
```

## 4. Monitoramento e Manutenção

### 4.1 Verificar TTL e Renovação
- Token padrão tem TTL de 24h conforme configurado
- Renovação automática é feita pelo External Secrets Operator
- Verificar TTL atual: `vault token lookup`

### 4.2 Troubleshooting Comum
1. Erro de autenticação:
   - Verificar se ServiceAccount existe
   - Verificar se role está correta
   - Verificar logs do Vault

2. Erro de acesso a secrets:
   - Verificar policy
   - Verificar path do secret
   - Verificar se secret existe no Vault

3. Erro de conexão:
   - Verificar URL do Vault
   - Verificar service do Vault
   - Verificar network policies

## 5. Boas Práticas
1. Sempre use TTLs razoáveis (24h é recomendado)
2. Monitore logs regularmente
3. Implemente network policies adequadas
4. Faça backup regular do Vault
5. Mantenha policies bem definidas e restritas
6. Use ServiceAccounts dedicados