#!/bin/bash

# Variáveis para os IPs que serão adicionados ao 'tls-san'
IP1=""
IP2=""
IP3=""

echo INICIANDO INSTALACAO RKE MENAGER
echo
sleep 2
echo Baixando RKE
cd /root/
curl -sfl https://get.rke2.io | sh -
sleep 2
sudo systemctl enable rke2-server.service
sleep 2 
sudo systemctl start rke2-server.service

echo CRIANDO DIRETORIO RANCHER
echo
sudo mkdir -p /etc/rancher/rke2/
sleep 2

# Caminho do arquivo que contém o token
TOKEN_FILE="/var/lib/rancher/rke2/server/node-token"

# Caminho onde o arquivo config.yaml será criado
CONFIG_FILE="/etc/rancher/rke2/config.yaml"

# Verifica se o arquivo do token existe
if [ -f "$TOKEN_FILE" ]; then
    # Lê o conteúdo do arquivo node-token
    TOKEN=$(cat $TOKEN_FILE)
else
    echo "Arquivo $TOKEN_FILE não encontrado!"
    exit 1
fi
echo

# Cria o arquivo de configuração e insere o conteúdo
cat <<EOF | sudo tee $CONFIG_FILE
token: $TOKEN
tls-san:
  - $IP1
  - $IP2
  - $IP3
etcd-disable-snapshots: true
etcd-snapshot-schedule-cron: "0 0 0 0 0"
EOF

# Exibe uma mensagem informando que o arquivo foi criado
echo "Arquivo $CONFIG_FILE criado com sucesso!"
echo

echo cat /var/lib/rancher/rke2/server/node-token
echo
sleep 5
sudo systemctl restart rke2-server.service
sleep 5 
cat /etc/rancher/rke2/rke2.yaml