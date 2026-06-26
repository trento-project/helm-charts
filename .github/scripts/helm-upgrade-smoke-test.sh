#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# === Display Utilities ===

# Print a section header.
# Args: $1 (string) - Section title
section() {
  printf '\n%s\n' "$1"
}

# Print a formatted banner with border.
# Args: $1 (string) - Banner text
banner() {
  printf '%s\n' "╔════════════════════════════════════════════════════════════════════════╗"
  printf '%s\n' "║$1║"
  printf '%s\n' "╚════════════════════════════════════════════════════════════════════════╝"
}

# === Health Check Functions ===

# Test Web service health endpoint.
# Args: $1 (string) - Base URL for Web service
# Returns: 0 if healthy, 1 if unhealthy
# Outputs: Health check status and result
test_web_health() {
  local web_url="$1"
  local response

  section "1. Testing Web health endpoint..."
  response=$(curl -sk "${web_url}/api/readyz" 2>/dev/null || echo "")
  echo "Web health: $response"

  if echo "$response" | grep -q "ready"; then
    echo "✅ Web is ready"
    return 0
  else
    echo "⚠️ Web health check returned: $response"
    return 1
  fi
}

# Test Wanda service health endpoint.
# Args: $1 (string) - Base URL for Wanda service
# Returns: 0 if healthy, 1 if unhealthy
# Outputs: Health check status and result
test_wanda_health() {
  local wanda_url="$1"
  local response

  echo ""
  section "2. Testing Wanda health endpoint..."
  response=$(curl -sk "${wanda_url}/api/readyz" 2>/dev/null || echo "")
  echo "Wanda health: $response"

  if echo "$response" | grep -q "ready"; then
    echo "✅ Wanda is ready"
    return 0
  else
    echo "⚠️ Wanda health check returned: $response"
    return 1
  fi
}

# === Authentication Functions ===

# Perform login and extract access token.
# Args: $1 (string) - Base URL for Web service
#       $2 (string) - Username
#       $3 (string) - Password
# Returns: 0 on success, 1 on failure
# Outputs: Access token to stdout on success
test_login() {
  local web_url="$1"
  local username="$2"
  local password="$3"
  local response access_token

  section "3. Testing login endpoint..."
  response=$(curl -sk -X POST "${web_url}/api/session" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" 2>/dev/null || echo "")

  echo "Login response: $response"

  access_token=$(echo "$response" | grep -o "\"access_token\":\"[^\"]*\"" | cut -d"\"" -f4)

  if [ -z "$access_token" ]; then
    echo "❌ Failed to get access token"
    return 1
  fi

  echo "✅ Login successful, token obtained"
  echo ""

  echo "$access_token"
  return 0
}

# === API Endpoint Tests ===

# Test user profile endpoint with authentication.
# Args: $1 (string) - Base URL for Web service
#       $2 (string) - Access token
#       $3 (string) - Expected username
# Returns: 0 on success, 1 on failure
# Outputs: Profile verification status
test_profile_endpoint() {
  local web_url="$1"
  local access_token="$2"
  local expected_username="$3"
  local response

  section "4. Testing profile endpoint..."
  response=$(curl -sk -X GET "${web_url}/api/v1/profile" \
    -H "Authorization: Bearer ${access_token}" 2>/dev/null || echo "")

  echo "Profile response: $response"

  if echo "$response" | grep -q "\"username\":\"${expected_username}\""; then
    echo "✅ Profile endpoint working - ${expected_username} user verified"
    return 0
  else
    echo "❌ Profile endpoint failed"
    return 1
  fi
}

# === MCP Server Tests ===

# Test MCP server initialization endpoint.
# Args: $1 (string) - Base URL for MCP service
#       $2 (string) - Access token
# Returns: 0 on success, 1 on failure
# Outputs: MCP server information and status
test_mcp_server() {
  local mcp_url="$1"
  local access_token="$2"
  local response server_name server_version

  echo ""
  section "5. Testing MCP server..."

  echo "   Testing MCP endpoint availability..."
  response=$(curl -sk -X POST "${mcp_url}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "clientInfo": {"name": "test-client", "version": "1.0.0"}, "capabilities": {}}}' 2>/dev/null || echo "")

  echo "   MCP initialize response (first event):"
  echo "$response" | head -3

  if echo "$response" | grep -q "serverInfo"; then
    server_name=$(echo "$response" | grep -o "\"name\":\"[^\"]*\"" | head -1 | cut -d\" -f4)
    server_version=$(echo "$response" | grep -o "\"version\":\"[^\"]*\"" | tail -1 | cut -d\" -f4)
    echo "   ✅ MCP server is responding: $server_name $server_version"
    return 0
  else
    echo "   ❌ MCP server response unexpected"
    echo "   Response: $response"
    return 1
  fi
}

# === Main Test Suite ===

# Run complete API smoke test suite.
# Uses: INGRESS_HOST, WEB_BASE_URL, WANDA_BASE_URL, MCP_BASE_URL environment variables
# Returns: 0 if all tests pass, 1 if any test fails
run_smoke_tests() {
  local ingress_host="${INGRESS_HOST:-trento-test.local}"
  local web_url="${WEB_BASE_URL:-https://${ingress_host}}"
  local wanda_url="${WANDA_BASE_URL:-https://${ingress_host}/wanda}"
  local mcp_url="${MCP_BASE_URL:-https://${ingress_host}/mcp}"
  local username="${TEST_USERNAME:-admin}"
  local password="${TEST_PASSWORD:-admin-test-password}"
  local access_token

  echo ""

  # Test health endpoints
  if ! test_web_health "$web_url"; then
    return 1
  fi

  if ! test_wanda_health "$wanda_url"; then
    return 1
  fi

  # Test authentication
  if ! access_token=$(test_login "$web_url" "$username" "$password"); then
    return 1
  fi

  # Test authenticated endpoints
  if ! test_profile_endpoint "$web_url" "$access_token" "$username"; then
    return 1
  fi

  # Test MCP server
  if ! test_mcp_server "$mcp_url" "$access_token"; then
    return 1
  fi

  echo ""
  banner "                      API TESTS PASSED                              "
  return 0
}

# Only run when executed directly (not when sourced for tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_smoke_tests
fi
