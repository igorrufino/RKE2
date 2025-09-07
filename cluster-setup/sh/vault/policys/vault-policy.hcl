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

path "auth/kubernetes/login" {
  capabilities = ["create", "read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
