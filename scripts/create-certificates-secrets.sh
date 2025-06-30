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
#     ├── ca_certificate.pem
#     ├── server_certificate.pem
#     ├── server_key.pem
#     ├── client_web_certificate.pem
#     ├── client_web_key.pem
#     ├── client_wanda_certificate.pem
#     └── client_wanda_key.pem
#
# The following secrets will be created:
#
# 1. rabbitmq-tls-server
#    - ca.crt    (from ca_certificate.pem)
#    - tls.crt   (from server_certificate.pem)
#    - tls.key   (from server_key.pem)
#
# 2. rabbitmq-tls-client-web
#    - ca.crt     (from ca_certificate.pem)
#    - client.crt (from client_web_certificate.pem)
#    - client.key (from client_web_key.pem)
#
# 3. rabbitmq-tls-client-wanda
#    - ca.crt     (from ca_certificate.pem)
#    - client.crt (from client_wanda_certificate.pem)
#    - client.key (from client_wanda_key.pem)
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
kubectl create secret generic rabbitmq-tls-server \
  --from-file=ca.crt=ca_certificate.pem \
  --from-file=tls.crt=server_certificate.pem \
  --from-file=tls.key=server_key.pem \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create secret for web client certificate and key
kubectl create secret generic rabbitmq-tls-client-web \
  --from-file=ca.crt=ca_certificate.pem \
  --from-file=client.crt=client_web_certificate.pem \
  --from-file=client.key=client_web_key.pem \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create secret for wanda client certificate and key
kubectl create secret generic rabbitmq-tls-client-wanda \
  --from-file=ca.crt=ca_certificate.pem \
  --from-file=client.crt=client_wanda_certificate.pem \
  --from-file=client.key=client_wanda_key.pem \
  --namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Kubernetes TLS secrets created in namespace: $NAMESPACE"

# List the created secrets
kubectl get secrets -n $NAMESPACE -o wide | grep rabbitmq-tls

popd
