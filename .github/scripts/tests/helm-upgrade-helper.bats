#!/usr/bin/env bats

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

# Test suite for helm-upgrade-helper.sh

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

  # Source the main helper script to test individual functions
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/helm-upgrade-helper.sh"

  # Keep test flow explicit through run status checks.
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

# === Kubernetes Diagnostics Tests ===

@test "show_pods_status: displays pod status" {
  tmpdir="$(mktemp -d)"

  # Mock kubectl
  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pods" ]; then
  if [[ "$*" == *"field-selector"* ]]; then
    # No non-running pods
    exit 0
  else
    echo "NAME                    READY   STATUS    RESTARTS   AGE"
    echo "web-pod                 1/1     Running   0          10m"
    exit 0
  fi
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_pods_status
  [ "$status" -eq 0 ]
  [[ "$output" == *"All pods"* ]]
  [[ "$output" == *"Pods not running"* ]]

  rm -rf "$tmpdir"
}

@test "show_events: displays recent events by default" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "events" ]; then
  echo "LAST SEEN   TYPE      REASON    MESSAGE"
  echo "1m          Normal    Started   Started container"
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_events
  [ "$status" -eq 0 ]
  [[ "$output" == *"Recent events"* ]]

  rm -rf "$tmpdir"
}

@test "show_events: displays all events when sort_by parameter provided" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "events" ]; then
  echo "LAST SEEN   TYPE      REASON    MESSAGE"
  echo "1m          Normal    Started   Started container"
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_events "all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All events"* ]]

  rm -rf "$tmpdir"
}

@test "show_pod_logs: displays logs from all pods" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pods" ]; then
  echo "web-pod db-pod"
  exit 0
elif [ "$1" = "logs" ]; then
  echo "Sample log line from ${3}"
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_pod_logs 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pod logs"* ]]
  [[ "$output" == *"Pod: web-pod"* ]]

  rm -rf "$tmpdir"
}

@test "show_pod_logs: shows previous logs when requested" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pods" ]; then
  echo "web-pod"
  exit 0
elif [ "$1" = "logs" ]; then
  if [[ "$*" == *"--previous"* ]]; then
    echo "Previous log"
  else
    echo "Current log"
  fi
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_pod_logs 10 "Recent " "true"
  [ "$status" -eq 0 ]
  [[ "$output" == *"previous"* ]]

  rm -rf "$tmpdir"
}

@test "show_failed_pod_logs: displays logs only from failed pods" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pods" ]; then
  echo "failed-pod"
  exit 0
elif [ "$1" = "logs" ]; then
  echo "Error log from failed pod"
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_failed_pod_logs
  [ "$status" -eq 0 ]
  [[ "$output" == *"failed-pod"* ]]

  rm -rf "$tmpdir"
}

@test "show_failed_pod_logs: shows success message when no failed pods" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pods" ]; then
  # Return empty string (no failed pods)
  echo ""
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_failed_pod_logs
  [ "$status" -eq 0 ]
  [[ "$output" == *"No failed or pending pods"* ]]

  rm -rf "$tmpdir"
}

# === Diagnostic Suites Tests ===

@test "post_install_diagnostics: runs all post-install checks" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ]; then
  echo "mock-output"
fi
exit 0
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run post_install_diagnostics
  [ "$status" -eq 0 ]
  [[ "$output" == *"POST-INSTALL DIAGNOSTICS"* ]]
  [[ "$output" == *"DIAGNOSTICS COMPLETE"* ]]

  rm -rf "$tmpdir"
}

@test "post_upgrade_diagnostics: runs all post-upgrade checks" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
echo "mock-output"
exit 0
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run post_upgrade_diagnostics
  [ "$status" -eq 0 ]
  [[ "$output" == *"POST-UPGRADE DIAGNOSTICS"* ]]
  [[ "$output" == *"DIAGNOSTICS COMPLETE"* ]]

  rm -rf "$tmpdir"
}

@test "failure_diagnostics: runs comprehensive failure diagnostics" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
echo "mock-output"
exit 0
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run failure_diagnostics
  [ "$status" -eq 0 ]
  [[ "$output" == *"FAILURE DIAGNOSTICS"* ]]
  [[ "$output" == *"FULL LOGS"* ]]

  rm -rf "$tmpdir"
}

@test "show_web_init_logs: displays web pod init container logs" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pod" ]; then
  echo "web-pod-12345"
  exit 0
elif [ "$1" = "logs" ]; then
  echo "Running DB migration..."
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_web_init_logs
  [ "$status" -eq 0 ]
  [[ "$output" == *"Web init container logs"* ]]
  [[ "$output" == *"DB migration"* ]]

  rm -rf "$tmpdir"
}

@test "show_web_init_logs: handles missing web pod" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pod" ]; then
  # No pods found
  echo ""
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/kubectl"

  export TRENTO_NAMESPACE="test-ns"
  PATH="$tmpdir:$PATH"
  run show_web_init_logs
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to find web pod"* ]]

  rm -rf "$tmpdir"
}

# === Version Comparison Tests ===

@test "compare_versions: shows version changes correctly" {
  tmpdir="$(mktemp -d)"
  current_file="$tmpdir/current.txt"
  new_file="$tmpdir/new.txt"

  # Current images
  cat > "$current_file" << 'EOF'
web|web-container|container|ghcr.io/org/web:v1.0.0
db|postgres|container|docker.io/postgres:14.0
EOF

  # New images
  cat > "$new_file" << 'EOF'
web|ghcr.io/org/web:v1.1.0
db|docker.io/postgres:15.0
cache|docker.io/redis:7.0
EOF

  run compare_versions "$current_file" "$new_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTAINER VERSION COMPARISON"* ]]
  [[ "$output" == *"web"* ]]
  [[ "$output" == *"v1.0.0"* ]]
  [[ "$output" == *"v1.1.0"* ]]

  rm -rf "$tmpdir"
}

@test "compare_versions: marks new images correctly" {
  tmpdir="$(mktemp -d)"
  current_file="$tmpdir/current.txt"
  new_file="$tmpdir/new.txt"

  # Current images (empty)
  touch "$current_file"

  # New images
  cat > "$new_file" << 'EOF'
web|ghcr.io/org/web:v1.0.0
EOF

  run compare_versions "$current_file" "$new_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"🆕"* ]]

  rm -rf "$tmpdir"
}

@test "compare_versions: shows unchanged images" {
  tmpdir="$(mktemp -d)"
  current_file="$tmpdir/current.txt"
  new_file="$tmpdir/new.txt"

  # Same images
  cat > "$current_file" << 'EOF'
web|web-container|container|ghcr.io/org/web:v1.0.0
EOF

  cat > "$new_file" << 'EOF'
web|ghcr.io/org/web:v1.0.0
EOF

  run compare_versions "$current_file" "$new_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅"* ]]

  rm -rf "$tmpdir"
}

@test "compare_container_versions: extracts and compares images" {
  tmpdir="$(mktemp -d)"

  # Mock kubectl
  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "get" ] && [ "$2" = "pods" ]; then
  cat << 'JSON'
{
  "items": [
    {
      "metadata": {"labels": {"app.kubernetes.io/name": "web"}},
      "spec": {
        "containers": [{"name": "web", "image": "ghcr.io/org/web:v1.0.0"}]
      }
    }
  ]
}
JSON
fi
exit 0
EOF
  chmod +x "$tmpdir/kubectl"

  # Mock helm
  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "template" ]; then
  cat << 'YAML'
spec:
  containers:
  - image: "ghcr.io/org/web:v1.1.0"
YAML
fi
exit 0
EOF
  chmod +x "$tmpdir/helm"

  # Mock jq
  cat > "$tmpdir/jq" << 'EOF'
#!/usr/bin/env bash
# Simple mock that passes through
cat
EOF
  chmod +x "$tmpdir/jq"

  export TRENTO_NAMESPACE="test-ns"
  export CHART_DIR="test-chart"
  export HELM_COMMON_FLAGS=""
  PATH="$tmpdir:$PATH"

  run compare_container_versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"Extracting current deployed images"* ]]
  [[ "$output" == *"Extracting new chart images"* ]]

  rm -rf "$tmpdir"
}

# === API Testing Tests ===

@test "verify_api: configures ingress and runs smoke tests" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/kubectl" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"ingress"* ]]; then
  echo "192.168.1.100"
  exit 0
elif [[ "$*" == *"certificaterequest"* ]]; then
  echo "No CertificateRequests found"
  exit 0
fi
exit 0
EOF
  chmod +x "$tmpdir/kubectl"

  cat > "$tmpdir/sudo" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$tmpdir/sudo"

  # Create mock smoke test script
  mkdir -p "$tmpdir/scripts"
  cat > "$tmpdir/scripts/helm-upgrade-smoke-test.sh" << 'EOF'
#!/usr/bin/env bash
echo "Smoke tests passed"
exit 0
EOF
  chmod +x "$tmpdir/scripts/helm-upgrade-smoke-test.sh"

  export TRENTO_NAMESPACE="test-ns"
  export TRENTO_WEB_ORIGIN="test.local"
  export REPO_ROOT="$tmpdir"
  mkdir -p "$REPO_ROOT/.github/scripts"
  cp "$tmpdir/scripts/helm-upgrade-smoke-test.sh" "$REPO_ROOT/.github/scripts/"

  PATH="$tmpdir:$PATH"
  run verify_api
  [ "$status" -eq 0 ]
  [[ "$output" == *"API FUNCTIONALITY TEST"* ]]

  rm -rf "$tmpdir"
}
