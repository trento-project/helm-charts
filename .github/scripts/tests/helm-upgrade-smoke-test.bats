#!/usr/bin/env bats

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

# Test suite for helm-upgrade-smoke-test.sh

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

  # Source the script to test individual functions
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/helm-upgrade-smoke-test.sh"

  # Keep test flow explicit through `run` status checks.
  set +e

  # Create temporary directory for test artifacts
  TEST_TMP="$(mktemp -d)"
}

teardown() {
  # Clean up test artifacts
  rm -rf "$TEST_TMP"
}

# === Display Utilities Tests ===

@test "section: outputs formatted section header" {
  run section "Test Section"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Test Section"* ]]
}

@test "banner: outputs formatted banner with borders" {
  run banner "Test Banner"
  [ "$status" -eq 0 ]
  [[ "$output" == *"╔"* ]]
  [[ "$output" == *"╚"* ]]
  [[ "$output" == *"Test Banner"* ]]
}

# === Health Check Tests ===

@test "test_web_health: succeeds when service is ready" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"ready"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_web_health "https://test.local"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Web is ready"* ]]

  rm -rf "$tmpdir"
}

@test "test_web_health: fails when service is not ready" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"not ready"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_web_health "https://test.local"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Web health check returned"* ]]

  rm -rf "$tmpdir"
}

@test "test_web_health: handles curl failure gracefully" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_web_health "https://test.local"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_wanda_health: succeeds when service is ready" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"ready"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_wanda_health "https://test.local/wanda"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Wanda is ready"* ]]

  rm -rf "$tmpdir"
}

@test "test_wanda_health: fails when service is not ready" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"unhealthy"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_wanda_health "https://test.local/wanda"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Wanda health check returned"* ]]

  rm -rf "$tmpdir"
}

# === Authentication Tests ===

@test "test_login: successfully obtains access token" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/session"* ]]; then
  echo '{"access_token":"test-token-12345","refresh_token":"refresh-test"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "password123"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Login successful"* ]]
  [[ "$output" == *"test-token-12345"* ]]

  rm -rf "$tmpdir"
}

@test "test_login: fails when no access token in response" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/session"* ]]; then
  echo '{"error":"invalid credentials"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "wrongpass"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to get access token"* ]]

  rm -rf "$tmpdir"
}

@test "test_login: handles curl failure" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "password"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_login: extracts token from JSON response correctly" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/session"* ]]; then
  echo '{"access_token":"abc123def456","user":{"username":"admin"}}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "password"
  [ "$status" -eq 0 ]
  # Last line should be the token
  token=$(echo "$output" | tail -1)
  [ "$token" = "abc123def456" ]

  rm -rf "$tmpdir"
}

# === API Endpoint Tests ===

@test "test_profile_endpoint: succeeds when profile matches expected username" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/v1/profile"* ]]; then
  echo '{"username":"admin","email":"admin@test.com","role":"admin"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_profile_endpoint "https://test.local" "test-token" "admin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Profile endpoint working"* ]]
  [[ "$output" == *"admin user verified"* ]]

  rm -rf "$tmpdir"
}

@test "test_profile_endpoint: fails when username doesn't match" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/v1/profile"* ]]; then
  echo '{"username":"other-user","email":"other@test.com"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_profile_endpoint "https://test.local" "test-token" "admin"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Profile endpoint failed"* ]]

  rm -rf "$tmpdir"
}

@test "test_profile_endpoint: fails on curl error" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_profile_endpoint "https://test.local" "test-token" "admin"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_profile_endpoint: sends authorization header correctly" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"Bearer test-token-123"* ]]; then
  echo '{"username":"admin"}'
  exit 0
fi
echo '{"error":"unauthorized"}'
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_profile_endpoint "https://test.local" "test-token-123" "admin"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

# === MCP Server Tests ===

@test "test_mcp_server: succeeds when MCP server responds correctly" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"initialize"* ]]; then
  cat << 'JSON'
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "serverInfo": {
      "name": "trento-mcp-server",
      "version": "1.0.0"
    },
    "capabilities": {}
  }
}
JSON
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_mcp_server "https://test.local/mcp" "test-token"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MCP server is responding"* ]]
  [[ "$output" == *"trento-mcp-server"* ]]

  rm -rf "$tmpdir"
}

@test "test_mcp_server: fails when no serverInfo in response" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"initialize"* ]]; then
  echo '{"jsonrpc":"2.0","id":1,"error":{"code":-32600,"message":"Invalid request"}}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_mcp_server "https://test.local/mcp" "test-token"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MCP server response unexpected"* ]]

  rm -rf "$tmpdir"
}

@test "test_mcp_server: handles curl failure" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_mcp_server "https://test.local/mcp" "test-token"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_mcp_server: extracts server name and version correctly" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
cat << 'JSON'
{
  "result": {
    "serverInfo": {
      "name": "my-mcp-server",
      "version": "2.1.3"
    }
  }
}
JSON
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_mcp_server "https://test.local/mcp" "token"
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-mcp-server 2.1.3"* ]]

  rm -rf "$tmpdir"
}

# === Integration Tests ===

@test "run_smoke_tests: succeeds when all tests pass" {
  tmpdir="$(mktemp -d)"

  # Mock curl for all endpoints
  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"ready"}'
elif [[ "$*" == *"/api/session"* ]]; then
  echo '{"access_token":"test-token-abc123"}'
elif [[ "$*" == *"/api/v1/profile"* ]]; then
  echo '{"username":"admin","email":"admin@test.com"}'
elif [[ "$*" == *"initialize"* ]]; then
  echo '{"result":{"serverInfo":{"name":"trento-mcp-server","version":"1.0.0"}}}'
else
  echo '{}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  export INGRESS_HOST="test.local"
  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 0 ]
  [[ "$output" == *"API TESTS PASSED"* ]]

  rm -rf "$tmpdir"
}

@test "run_smoke_tests: fails when web health check fails" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"unhealthy"}'
else
  echo '{}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  export INGRESS_HOST="test.local"
  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 1 ]
  [[ "$output" != *"API TESTS PASSED"* ]]

  rm -rf "$tmpdir"
}

@test "run_smoke_tests: fails when login fails" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"ready"}'
elif [[ "$*" == *"/api/session"* ]]; then
  echo '{"error":"invalid credentials"}'
else
  echo '{}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  export INGRESS_HOST="test.local"
  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to get access token"* ]]

  rm -rf "$tmpdir"
}

@test "run_smoke_tests: uses environment variables for configuration" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
# Echo the URL to verify it's using the custom values
if [[ "$*" == *"custom-host.example.com"* ]]; then
  echo "CUSTOM_URL_DETECTED"
fi
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"ready"}'
elif [[ "$*" == *"/api/session"* ]]; then
  echo '{"access_token":"token123"}'
elif [[ "$*" == *"/api/v1/profile"* ]]; then
  echo '{"username":"customadmin"}'
elif [[ "$*" == *"initialize"* ]]; then
  echo '{"result":{"serverInfo":{"name":"mcp","version":"1.0"}}}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  export INGRESS_HOST="custom-host.example.com"
  export TEST_USERNAME="customadmin"
  export TEST_PASSWORD="custompass"
  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 0 ]
  [[ "$output" == *"CUSTOM_URL_DETECTED"* ]]

  rm -rf "$tmpdir"
}

@test "run_smoke_tests: tests all endpoints in sequence" {
  tmpdir="$(mktemp -d)"

  # Track which endpoints were called
  call_log="$tmpdir/calls.log"
  touch "$call_log"

  cat > "$tmpdir/curl" << EOF
#!/usr/bin/env bash
if [[ "\$*" == *"/api/readyz"* ]]; then
  if [[ "\$*" == *"wanda"* ]]; then
    echo "wanda-health" >> "$call_log"
  else
    echo "web-health" >> "$call_log"
  fi
  echo '{"status":"ready"}'
elif [[ "\$*" == *"/api/session"* ]]; then
  echo "login" >> "$call_log"
  echo '{"access_token":"token"}'
elif [[ "\$*" == *"/api/v1/profile"* ]]; then
  echo "profile" >> "$call_log"
  echo '{"username":"admin"}'
elif [[ "\$*" == *"initialize"* ]]; then
  echo "mcp" >> "$call_log"
  echo '{"result":{"serverInfo":{"name":"mcp","version":"1"}}}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  export INGRESS_HOST="test.local"
  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 0 ]

  # Verify all endpoints were called
  grep -q "web-health" "$call_log"
  grep -q "wanda-health" "$call_log"
  grep -q "login" "$call_log"
  grep -q "profile" "$call_log"
  grep -q "mcp" "$call_log"

  rm -rf "$tmpdir"
}

# === Additional Edge Cases ===

@test "test_login: handles malformed JSON response" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
echo '{"access_token":"incomplete'
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "password"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_profile_endpoint: handles empty response" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
echo ''
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_profile_endpoint "https://test.local" "token" "admin"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_mcp_server: handles timeout gracefully" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
# Simulate timeout with no output
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_mcp_server "https://test.local/mcp" "token"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "run_smoke_tests: stops on first failure" {
  tmpdir="$(mktemp -d)"

  call_log="$tmpdir/calls.log"
  touch "$call_log"

  cat > "$tmpdir/curl" << EOF
#!/usr/bin/env bash
if [[ "\$*" == *"/api/readyz"* ]] && [[ "\$*" != *"wanda"* ]]; then
  echo "web-health" >> "$call_log"
  echo '{"status":"ready"}'
elif [[ "\$*" == *"wanda"* ]]; then
  echo "wanda-health" >> "$call_log"
  echo '{"status":"unhealthy"}'
else
  echo "should-not-reach" >> "$call_log"
  echo '{}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  export INGRESS_HOST="test.local"
  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 1 ]

  # Verify it stopped after wanda health failure
  grep -q "web-health" "$call_log"
  grep -q "wanda-health" "$call_log"
  ! grep -q "should-not-reach" "$call_log"

  rm -rf "$tmpdir"
}

@test "test_login: handles rate limiting response" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
echo '{"error":"rate_limit_exceeded","retry_after":60}'
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "password"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to get access token"* ]]

  rm -rf "$tmpdir"
}

@test "test_profile_endpoint: handles expired token" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
echo '{"error":"token_expired","message":"Please re-authenticate"}'
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_profile_endpoint "https://test.local" "expired-token" "admin"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "test_mcp_server: validates JSON-RPC response format" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
cat << 'JSON'
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05"
  }
}
JSON
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_mcp_server "https://test.local/mcp" "token"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unexpected"* ]]

  rm -rf "$tmpdir"
}

@test "run_smoke_tests: uses default credentials when env vars not set" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"admin-test-password"* ]]; then
  echo "DEFAULT_PASSWORD_DETECTED"
fi
if [[ "$*" == *"/api/readyz"* ]]; then
  echo '{"status":"ready"}'
elif [[ "$*" == *"/api/session"* ]]; then
  echo '{"access_token":"token"}'
elif [[ "$*" == *"/api/v1/profile"* ]]; then
  echo '{"username":"admin"}'
elif [[ "$*" == *"initialize"* ]]; then
  echo '{"result":{"serverInfo":{"name":"mcp","version":"1"}}}'
fi
exit 0
EOF
  chmod +x "$tmpdir/curl"

  # Explicitly unset env vars
  unset TEST_USERNAME
  unset TEST_PASSWORD
  export INGRESS_HOST="test.local"

  PATH="$tmpdir:$PATH"
  run run_smoke_tests
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEFAULT_PASSWORD_DETECTED"* ]]

  rm -rf "$tmpdir"
}

@test "test_login: sanitizes password from output" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
echo '{"access_token":"token123"}'
exit 0
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "secret-password-123"
  [ "$status" -eq 0 ]
  # Password should not appear in output
  [[ "$output" != *"secret-password-123"* ]]

  rm -rf "$tmpdir"
}

@test "test_web_health: uses -k flag for insecure connections" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"-k"* ]]; then
  echo '{"status":"ready"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_web_health "https://test.local"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "test_login: sends correct Content-Type header" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/curl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"Content-Type: application/json"* ]]; then
  echo '{"access_token":"token"}'
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/curl"

  PATH="$tmpdir:$PATH"
  run test_login "https://test.local" "admin" "password"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}
