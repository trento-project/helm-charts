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

  section "3. Testing login endpoint..." >&2
  response=$(curl -sk -X POST "${web_url}/api/session" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" 2>/dev/null || echo "")

  echo "Login response: $response" >&2

  access_token=$(echo "$response" | grep -o "\"access_token\":\"[^\"]*\"" | cut -d"\"" -f4)

  if [ -z "$access_token" ]; then
    echo "❌ Failed to get access token" >&2
    return 1
  fi

  echo "✅ Login successful, token obtained" >&2
  echo "" >&2

  echo "$access_token"
  return 0
}

# Fetch the generated collector API key using an authenticated access token.
# Args: $1 (string) - Base URL for Web service
#       $2 (string) - Access token
# Returns: 0 on success, 1 on failure
# Outputs: API key to stdout on success
fetch_api_key() {
  local web_url="$1"
  local access_token="$2"
  local response api_key

  response=$(curl -sk -X GET "${web_url}/api/v1/settings/api_key" \
    -H "Authorization: Bearer ${access_token}" 2>/dev/null || echo "")

  api_key=$(echo "$response" | grep -o "\"generated_api_key\":\"[^\"]*\"" | cut -d'"' -f4)

  if [ -z "$api_key" ]; then
    echo "❌ Failed to fetch API key: ${response}" >&2
    return 1
  fi

  echo "$api_key"
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

# Test activity log endpoint with authentication.
# Args: $1 (string) - Base URL for Web service
#       $2 (string) - Access token
# Returns: 0 on success, 1 on failure
# Outputs: Activity log verification status
test_activity_log_endpoint() {
  local web_url="$1"
  local access_token="$2"
  local response http_code

  section "4b. Testing activity log endpoint..."
  response=$(curl -sk -w '\n%{http_code}' -X GET "${web_url}/api/v1/activity_log" \
    -H "Authorization: Bearer ${access_token}" 2>/dev/null || echo "")
  http_code=$(echo "$response" | tail -n1)

  echo "Activity log response status: $http_code"

  if [ "$http_code" = "200" ]; then
    echo "✅ Activity log endpoint working"
    return 0
  else
    echo "❌ Activity log endpoint failed"
    echo "Response: $(echo "$response" | sed '$d')"
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

# === Data Seeding ===

# Seed the running Trento instance with realistic demo data via photofinish, so
# meaningful DB volume (hosts, SAP systems, HA clusters, activity logs, ...)
# exists before a chart upgrade is exercised against it.
# Uses: INGRESS_HOST, TRENTO_ADMIN_USER, TRENTO_ADMIN_PASSWORD, PHOTOFINISH_BIN,
#       FIXTURES_DIR environment variables
# Returns: 0 on success, 1 on failure
seed_demo_data() {
  local ingress_host="${INGRESS_HOST:-trento-test.local}"
  local web_url="https://${ingress_host}"
  local username="${TRENTO_ADMIN_USER:-admin}"
  local password="${TRENTO_ADMIN_PASSWORD:-admin-test-password}"
  local photofinish_bin="${PHOTOFINISH_BIN:-photofinish}"
  local fixtures_dir="${FIXTURES_DIR:?FIXTURES_DIR must point at a checkout containing .photofinish.toml}"
  local access_token api_key

  banner "                         SEEDING DEMO DATA                              "

  if ! access_token=$(test_login "$web_url" "$username" "$password"); then
    return 1
  fi

  section "=== Fetching collector API key ==="
  if ! api_key=$(fetch_api_key "$web_url" "$access_token"); then
    return 1
  fi
  echo "API key obtained"

  section "=== Running photofinish 'demo' scenario ==="
  (
    cd "$fixtures_dir"
    "$photofinish_bin" run demo -k -u "${web_url}/api/v1/collect" "$api_key"
  )

  banner "                      DEMO DATA SEEDED                                  "
  return 0
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

  if ! test_activity_log_endpoint "$web_url" "$access_token"; then
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
  case "${1:-}" in
    seed)
      seed_demo_data
      ;;
    *)
      run_smoke_tests
      ;;
  esac
  exit $?
fi
