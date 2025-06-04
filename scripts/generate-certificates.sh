#!/bin/bash

#
# Script: Generate Stub SSL Certificates
#
# Description:
# This script generates self-signed SSL certificates for testing and development purposes.
# It creates a Certificate Authority (CA), server certificates, and client certificates
# using OpenSSL. These certificates are intended for non-production environments only.
#
# Usage:
#   ./generate_certs.sh [base_directory]
#
# Arguments:
#   base_directory    Optional. Base directory where certificates will be generated.
#                    If not specified, current directory will be used.
#
# Requirements:
#   - OpenSSL must be installed on the system
#   - Proper write permissions in the current directory
#
# Note:
# The generated certificates should NOT be used in production environments.
# They are intended for development and testing purposes only.
#

set -euo pipefail

dir=${1:-"./certs"}
RABBITMQ_HOSTNAME=${RABBITMQ_HOSTNAME:-"trento-server-rabbitmq"}

mkdir -p $dir
pushd $dir

# Directory structure setup
mkdir -p ca server clients/web clients/wanda


# Generate CA
openssl genrsa -out ca/ca.key 4096
openssl req -new -x509 -days 3650 -key ca/ca.key -out ca/ca.crt \
  -subj "/CN=$RABBITMQ_HOSTNAME/O=Certificate Authority"

# Generate RabbitMQ server certificates
openssl genrsa -out server/server.key 4096
openssl req -new -key server/server.key -out server/server.csr \
  -subj "/CN=$RABBITMQ_HOSTNAME/O=RabbitMQ Server" \
  -addext "subjectAltName = DNS:$RABBITMQ_HOSTNAME"
openssl x509 -req -days 365 -in server/server.csr \
  -CA ca/ca.crt -CAkey ca/ca.key -CAcreateserial \
  -out server/server.crt -extfile <(printf "subjectAltName=DNS:$RABBITMQ_HOSTNAME")

# Generate client certificates for web
openssl genrsa -out clients/web/web.key 4096
openssl req -new -key clients/web/web.key -out clients/web/web.csr \
  -subj "/CN=web/O=Client Application"
openssl x509 -req -days 365 -in clients/web/web.csr \
  -CA ca/ca.crt -CAkey ca/ca.key -CAcreateserial \
  -out clients/web/web.crt

# Generate client certificates for wanda
openssl genrsa -out clients/wanda/wanda.key 4096
openssl req -new -key clients/wanda/wanda.key -out clients/wanda/wanda.csr \
  -subj "/CN=wanda/O=Client Application"
openssl x509 -req -days 365 -in clients/wanda/wanda.csr \
  -CA ca/ca.crt -CAkey ca/ca.key -CAcreateserial \
  -out clients/wanda/wanda.crt

# Create PEM bundles
cat server/server.crt server/server.key > server/server.pem
cat clients/web/web.crt clients/web/web.key > clients/web/web.pem
cat clients/wanda/wanda.crt clients/wanda/wanda.key > clients/wanda/wanda.pem

# Set permissions
chmod 400 server/server.key clients/web/web.key clients/wanda/wanda.key
rm -f server/server.csr clients/web/web.csr clients/wanda/wanda.csr  # Cleanup CSRs

echo "Generated files in $dir:"
tree -I '*.csr'

popd
