-- Comando para pegar a senha do postgres 
kubectl get secret postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode; echo

-- Comando acessar o pod do postgres
kubectl exec -i -t -n default postgres-postgresql-0 -c postgresql -- sh -c "clear; (bash || ash || sh)"

-- 1.Conectar ao banco de dados postgres
psql -U postgres -d postgres

-- 2. Criar um usuário dedicado para o Vault
CREATE USER vault_user WITH PASSWORD 'use-a-strong-password';


-- 3. Criar um banco de dados para o Vault
CREATE DATABASE vault;

-- 4. Conectar ao banco de dados postgres com ususario root mas no banco vault
\c vault
ou
psql -U postgres -d vault

-- 5. Conceder privilégios ao usuário no banco de dados
GRANT ALL PRIVILEGES ON DATABASE vault TO vault_user;

-- Conecte-se ao banco vault antes de executar o restante dos comandos
-- No DBeaver, você precisará estabelecer uma nova conexão com o banco 'vault'
-- ou mudar para ele depois de criá-lo

-- 6. Dar a o usuário do Vault acesso ao esquema público
GRANT USAGE, CREATE ON SCHEMA public TO vault_user;

-- 7. Conectar-se ao banco de dados com o usuário criado
\c vault vault_user

ou
psql -U vault_user -d vault

-- 8. Criar a tabela principal para armazenamento
CREATE TABLE vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT pkey PRIMARY KEY (path, key)
);

-- 9. Criar o índice para melhorar a performance
CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);

-- 10. Criar a tabela para suporte a High Availability
CREATE TABLE vault_ha_locks (
  ha_key                                      TEXT COLLATE "C" NOT NULL,
  ha_identity                                 TEXT COLLATE "C" NOT NULL,
  ha_value                                    TEXT COLLATE "C",
  valid_until                                 TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT ha_key PRIMARY KEY (ha_key)
);

-- 11. Conceder privilégios específicos para o usuário do Vault
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vault_user;