#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

section() {
  printf '\n%s\n' "$1"
}

banner() {
  printf '%s\n' "╔════════════════════════════════════════════════════════════════════════╗"
  printf '%s\n' "║$1║"
  printf '%s\n' "╚════════════════════════════════════════════════════════════════════════╝"
}

# Test via ingress (TLS) by default, can override with localhost URLs
INGRESS_HOST="${INGRESS_HOST:-trento-test.local}"
WEB_BASE_URL="${WEB_BASE_URL:-https://${INGRESS_HOST}}"
WANDA_BASE_URL="${WANDA_BASE_URL:-https://${INGRESS_HOST}/wanda}"
MCP_BASE_URL="${MCP_BASE_URL:-https://${INGRESS_HOST}/mcp}"

echo ""
section "1. Testing Web health endpoint..."
WEB_RESPONSE=$(curl -sk "${WEB_BASE_URL}/api/readyz")
echo "Web health: $WEB_RESPONSE"

if echo "$WEB_RESPONSE" | grep -q "ready"; then
  echo "✅ Web is ready"
else
  echo "⚠️ Web health check returned: $WEB_RESPONSE"
fi

echo ""
section "2. Testing Wanda health endpoint..."
WANDA_RESPONSE=$(curl -sk "${WANDA_BASE_URL}/api/readyz")
echo "Wanda health: $WANDA_RESPONSE"

if echo "$WANDA_RESPONSE" | grep -q "ready"; then
  echo "✅ Wanda is ready"
else
  echo "⚠️ Wanda health check returned: $WANDA_RESPONSE"
fi

section "3. Testing login endpoint..."
LOGIN_RESPONSE=$(curl -sk -X POST "${WEB_BASE_URL}/api/session" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"admin\", \"password\": \"admin-test-password\"}")

echo "Login response: $LOGIN_RESPONSE"

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o "\"access_token\":\"[^\"]*\"" | cut -d"\"" -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

echo "✅ Login successful, token obtained"
echo ""

section "4. Testing profile endpoint..."
PROFILE_RESPONSE=$(curl -sk -X GET "${WEB_BASE_URL}/api/v1/profile" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "Profile response: $PROFILE_RESPONSE"

if echo "$PROFILE_RESPONSE" | grep -q "\"username\":\"admin\""; then
  echo "✅ Profile endpoint working - admin user verified"
else
  echo "❌ Profile endpoint failed"
  exit 1
fi

echo ""
section "5. Testing MCP server..."

echo "   Testing MCP endpoint availability..."
INIT_RESPONSE=$(curl -sk -X POST "${MCP_BASE_URL}/mcp" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"initialize\", \"params\": {\"protocolVersion\": \"2024-11-05\", \"clientInfo\": {\"name\": \"test-client\", \"version\": \"1.0.0\"}, \"capabilities\": {}}}")

echo "   MCP initialize response (first event):"
echo "$INIT_RESPONSE" | head -3

if echo "$INIT_RESPONSE" | grep -q "serverInfo"; then
  SERVER_NAME=$(echo "$INIT_RESPONSE" | grep -o "\"name\":\"[^\"]*\"" | head -1 | cut -d\" -f4)
  SERVER_VERSION=$(echo "$INIT_RESPONSE" | grep -o "\"version\":\"[^\"]*\"" | tail -1 | cut -d\" -f4)
  echo "   ✅ MCP server is responding: $SERVER_NAME $SERVER_VERSION"
else
  echo "   ⚠️ MCP server response unexpected"
  echo "   Response: $INIT_RESPONSE"
fi

echo ""

banner "                      API TESTS PASSED                              "
