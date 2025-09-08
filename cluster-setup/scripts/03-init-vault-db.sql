-- Script de inicialização do banco Vault
-- 1. Criar usuário dedicado para o Vault
CREATE USER {{VAULT_USER}} WITH PASSWORD '{{VAULT_PASSWORD}}';

-- 2. Criar banco de dados para o Vault
CREATE DATABASE vault;

-- 3. Conceder privilégios ao usuário no banco de dados
GRANT ALL PRIVILEGES ON DATABASE vault TO {{VAULT_USER}};

-- 4. Conectar ao banco vault e configurar esquema
\c vault

-- 5. Dar ao usuário do Vault acesso ao esquema público
GRANT USAGE, CREATE ON SCHEMA public TO {{VAULT_USER}};

-- 6. Criar tabelas como usuário postgres primeiro
CREATE TABLE vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT pkey PRIMARY KEY (path, key)
);

-- 7. Criar índice para performance
CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);

-- 8. Criar tabela para High Availability
CREATE TABLE vault_ha_locks (
  ha_key                                      TEXT COLLATE "C" NOT NULL,
  ha_identity                                 TEXT COLLATE "C" NOT NULL,
  ha_value                                    TEXT COLLATE "C",
  valid_until                                 TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT ha_key PRIMARY KEY (ha_key)
);

-- 9. Conceder todos os privilégios para {{VAULT_USER}}
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO {{VAULT_USER}};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO {{VAULT_USER}};