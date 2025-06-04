#!/bin/bash

#
# Script: Upload PKI Certificates as Kubernetes Secrets
#
# Description:
# This script creates Kubernetes secrets from existing PKI certificates.
# It uploads CA certificates, server certificates, and client certificates
# to a specified namespace as Kubernetes secrets for use with RabbitMQ TLS.
#
# Usage:
#   ./create-certificates-secrets.sh [namespace] [certs_dir]
#
# Arguments:
#   namespace    Optional. Target namespace for the secrets.
#               If not specified, 'default' namespace is used.
#   certs_dir   Optional. Directory containing the certificates.
#               If not specified, current directory is used.
#
# Requirements:
#   - kubectl with proper cluster access
#   - Certificate files in the following structure:
#     /path/to/certificates/
#     ├── ca/
#     │   └── ca.crt
#     ├── server/
#     │   ├── server.crt
#     │   └── server.key
#     └── clients/
#         ├── web/
#         │   ├── web.crt
#         │   └── web.key
#         └── wanda/
#             ├── wanda.crt
#             └── wanda.key
#
# The following secrets will be created:
#
# 1. rabbitmq-server-tls
#    - ca.crt    (from ca/ca.crt)
#    - tls.crt   (from server/server.crt)
#    - tls.key   (from server/server.key)
#
# 2. rabbitmq-ca
#    - ca.crt    (from ca/ca.crt)
#
# 3. web-rabbitmq-client-tls
#    - ca.crt     (from ca/ca.crt)
#    - client.crt (from clients/web/web.crt)
#    - client.key (from clients/web/web.key)
#
# 4. wanda-rabbitmq-client-tls
#    - ca.crt     (from ca/ca.crt)
#    - client.crt (from clients/wanda/wanda.crt)
#    - client.key (from clients/wanda/wanda.key)
#

set -euo pipefail

# Namespace for secrets (customize as needed)
NAMESPACE=${1:-default}
# Directory containing the generated certificates
CERTS_DIR=${2:-"."}
# Ensure the namespace exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
# Ensure the directory exists
if [ ! -d "$CERTS_DIR" ]; then
  echo "Directory $CERTS_DIR does not exist. Please provide a valid directory containing the certificates."
  exit 1
fi


# Change to the directory containing the certificates
pushd "$CERTS_DIR"

# Create secret for RabbitMQ server's certificate and private key
kubectl create secret generic rabbitmq-server-tls \
  --from-file=ca.crt=ca/ca.crt \
  --from-file=tls.crt=server/server.crt \
  --from-file=tls.key=server/server.key \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create secret for CA certificate only (for trust distribution)
kubectl create secret generic rabbitmq-ca \
  --from-file=ca.crt=ca/ca.crt \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create secret for web client certificate and key
kubectl create secret generic web-rabbitmq-client-tls \
  --from-file=ca.crt=ca/ca.crt \
  --from-file=client.crt=clients/web/web.crt \
  --from-file=client.key=clients/web/web.key \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create secret for wanda client certificate and key
kubectl create secret generic wanda-rabbitmq-client-tls \
  --from-file=ca.crt=ca/ca.crt \
  --from-file=client.crt=clients/wanda/wanda.crt \
  --from-file=client.key=clients/wanda/wanda.key \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Kubernetes TLS secrets created in namespace: $NAMESPACE"

# List the created secrets
kubectl get secrets -n $NAMESPACE -o wide | grep rabbitmq

popd
