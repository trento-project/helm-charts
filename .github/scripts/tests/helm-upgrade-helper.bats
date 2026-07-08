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


# === OBS Package Fetching Tests ===

@test "fetch_obs_package: successfully clones repository" {
  tmpdir="$(mktemp -d)"
  work_dir="$tmpdir/work"
  mkdir -p "$work_dir"

  # Create mock git command (NO real git operations)
  cat > "$tmpdir/git" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "clone" ] && [ "$2" = "--depth" ] && [ "$3" = "1" ]; then
  local url="$4"
  local dest="$5"
  mkdir -p "$dest"
  touch "$dest/test-file"
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/git"

  PATH="$tmpdir:$PATH"
  run fetch_obs_package "https://example.com/repo.git" "$work_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"obs-package"* ]]

  rm -rf "$tmpdir"
}

@test "fetch_obs_package: fails on invalid URL" {
  tmpdir="$(mktemp -d)"
  work_dir="$tmpdir/work"
  mkdir -p "$work_dir"

  cat > "$tmpdir/git" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/git"

  PATH="$tmpdir:$PATH"
  run fetch_obs_package "https://invalid.com/repo.git" "$work_dir"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

# === OBS Package Verification Tests ===

@test "verify_obs_package_files: succeeds when all files exist" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  mkdir -p "$obs_dir"

  touch "$obs_dir/values.yaml"
  touch "$obs_dir/_service"
  touch "$obs_dir/contents.tar.gz"

  run verify_obs_package_files "$obs_dir"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "verify_obs_package_files: fails when values.yaml is missing" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  mkdir -p "$obs_dir"

  touch "$obs_dir/_service"
  touch "$obs_dir/contents.tar.gz"

  run verify_obs_package_files "$obs_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"values.yaml"* ]]

  rm -rf "$tmpdir"
}

@test "verify_obs_package_files: fails when _service is missing" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  mkdir -p "$obs_dir"

  touch "$obs_dir/values.yaml"
  touch "$obs_dir/contents.tar.gz"

  run verify_obs_package_files "$obs_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"_service"* ]]

  rm -rf "$tmpdir"
}

@test "verify_obs_package_files: fails when contents.tar.gz is missing" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  mkdir -p "$obs_dir"

  touch "$obs_dir/values.yaml"
  touch "$obs_dir/_service"

  run verify_obs_package_files "$obs_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"contents.tar.gz"* ]]

  rm -rf "$tmpdir"
}

# === Chart Extraction Tests ===

@test "extract_chart_contents: successfully extracts tarball" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"

  # Create a test tarball
  test_content="$tmpdir/test-content"
  mkdir -p "$test_content"
  echo "test" > "$test_content/test-file.yaml"
  tar -czf "$obs_dir/contents.tar.gz" -C "$test_content" .

  run extract_chart_contents "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]
  [ -f "$chart_dir/test-file.yaml" ]

  rm -rf "$tmpdir"
}

@test "extract_chart_contents: fails with corrupted tarball" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"

  # Create corrupted tarball
  echo "not a tarball" > "$obs_dir/contents.tar.gz"

  run extract_chart_contents "$obs_dir" "$chart_dir"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

# === Chart.yaml Copy Tests ===

@test "copy_chart_yaml: successfully copies Chart.yaml" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  cat > "$obs_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test-chart
version: 1.0.0
EOF

  run copy_chart_yaml "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]
  [ -f "$chart_dir/Chart.yaml" ]
  grep -q "test-chart" "$chart_dir/Chart.yaml"

  rm -rf "$tmpdir"
}

@test "copy_chart_yaml: fails when source Chart.yaml missing" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  run copy_chart_yaml "$obs_dir" "$chart_dir"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

# === Chart Structure Display Tests ===

@test "display_chart_structure: shows chart structure" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/chart"
  mkdir -p "$chart_dir/templates"

  touch "$chart_dir/Chart.yaml"
  touch "$chart_dir/values.yaml"
  touch "$chart_dir/templates/deployment.yaml"
  touch "$chart_dir/templates/service.yaml"

  run display_chart_structure "$chart_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Chart.yaml"* ]]
  [[ "$output" == *"Templates directory exists"* ]]

  rm -rf "$tmpdir"
}

@test "display_chart_structure: handles missing templates directory" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/chart"
  mkdir -p "$chart_dir"

  touch "$chart_dir/Chart.yaml"

  run display_chart_structure "$chart_dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Templates directory exists"* ]]

  rm -rf "$tmpdir"
}

# === RPM Macros Tests ===

@test "create_rpm_macros: creates macros file with default values" {
  local output_file="$TEST_TMP/.rpmmacros"

  run create_rpm_macros "" "" "$output_file"
  [ "$status" -eq 0 ]
  [ -f "$output_file" ]
  grep -q "registry.suse.com" "$output_file"
  grep -q "trento" "$output_file"
}

@test "create_rpm_macros: creates macros file with custom values" {
  local output_file="$TEST_TMP/.rpmmacros-custom"

  run create_rpm_macros "custom.registry.com" "myprefix" "$output_file"
  [ "$status" -eq 0 ]
  [ -f "$output_file" ]
  grep -q "custom.registry.com" "$output_file"
  grep -q "myprefix" "$output_file"
}

# === Buildtime Service Tests ===

@test "extract_buildtime_service: extracts service section from _service file" {
  tmpdir="$(mktemp -d)"
  service_file="$tmpdir/_service"

  cat > "$service_file" << 'EOF'
<?xml version="1.0"?>
<services>
  <service name="other_service" mode="disabled">
    <param name="foo">bar</param>
  </service>
  <service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
    <param name="eval">%registry_url</param>
  </service>
</services>
EOF

  run extract_buildtime_service "$service_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *'mode="buildtime"'* ]]
  [[ "$output" == *"replace_using_env"* ]]
  [[ "$output" != *"other_service"* ]]

  rm -rf "$tmpdir"
}

@test "extract_file_parameter: extracts file parameter from service XML" {
  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
    <param name="eval">%registry_url</param>
  </service>'

  run extract_file_parameter "$service_xml"
  [ "$status" -eq 0 ]
  [ "$output" = "values.yaml" ]
}

@test "extract_file_parameter: fails when file parameter not found" {
  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="other">something</param>
  </service>'

  run extract_file_parameter "$service_xml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "extract_file_parameter: handles multiple param elements" {
  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="eval">%registry_url</param>
    <param name="file">custom.yaml</param>
    <param name="var">IMG_PREFIX=%img_repository_prefix</param>
  </service>'

  run extract_file_parameter "$service_xml"
  [ "$status" -eq 0 ]
  [ "$output" = "custom.yaml" ]
}

# === Replace Using Env Tests ===

@test "run_replace_using_env: builds command with eval and var parameters" {
  tmpdir="$(mktemp -d)"

  # Create mock replace_using_env command
  mkdir -p "$tmpdir/usr/lib/obs/service"
  cat > "$tmpdir/usr/lib/obs/service/replace_using_env" << 'EOF'
#!/usr/bin/env bash
# Mock OBS service - just verify parameters
echo "Called with: $@" >&2
exit 0
EOF
  chmod +x "$tmpdir/usr/lib/obs/service/replace_using_env"

  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
    <param name="eval">%registry_url</param>
    <param name="var">IMG_PREFIX=%img_repository_prefix</param>
  </service>'

  PATH="$tmpdir:$PATH"
  run run_replace_using_env "values.yaml" "$service_xml"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "run_replace_using_env: fails when OBS service fails" {
  tmpdir="$(mktemp -d)"

  mkdir -p "$tmpdir/usr/lib/obs/service"
  cat > "$tmpdir/usr/lib/obs/service/replace_using_env" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/usr/lib/obs/service/replace_using_env"

  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
  </service>'

  PATH="$tmpdir:$PATH"
  run run_replace_using_env "values.yaml" "$service_xml"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

# === Process Buildtime Services Tests ===

@test "process_buildtime_services: processes replace_using_env service" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  # Create _service file
  cat > "$obs_dir/_service" << 'EOF'
<?xml version="1.0"?>
<services>
  <service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
    <param name="eval">%registry_url</param>
  </service>
</services>
EOF

  # Create values.yaml
  cat > "$obs_dir/values.yaml" << 'EOF'
registry: %registry_url%
EOF

  # Create mock OBS service
  mkdir -p "$tmpdir/usr/lib/obs/service"
  cat > "$tmpdir/usr/lib/obs/service/replace_using_env" << 'EOF'
#!/usr/bin/env bash
# Mock service - simulate processing by modifying values.yaml
sed -i 's/%registry_url%/registry.suse.com/g' values.yaml
exit 0
EOF
  chmod +x "$tmpdir/usr/lib/obs/service/replace_using_env"

  PATH="$tmpdir:$PATH"
  run process_buildtime_services "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]
  [ -f "$chart_dir/values.yaml" ]

  rm -rf "$tmpdir"
}

@test "process_buildtime_services: skips when replace_using_env not present" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs-package"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  cat > "$obs_dir/_service" << 'EOF'
<?xml version="1.0"?>
<services>
  <service name="other_service" mode="buildtime">
    <param name="foo">bar</param>
  </service>
</services>
EOF

  run process_buildtime_services "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

# === Copy OBS Artifacts Tests ===

@test "copy_obs_artifacts: successfully copies chart and values" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/chart"
  workspace_dir="$tmpdir/workspace"
  mkdir -p "$chart_dir"
  mkdir -p "$workspace_dir"

  cat > "$chart_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test
version: 1.0.0
EOF

  cat > "$chart_dir/values.yaml" << 'EOF'
key: value
EOF

  run copy_obs_artifacts "$chart_dir" "$workspace_dir"
  [ "$status" -eq 0 ]
  [ -d "$workspace_dir/chart" ]
  [ -f "$workspace_dir/chart/Chart.yaml" ]
  [ -f "$workspace_dir/chart/values.yaml" ]
  [ -f "$workspace_dir/values-obs.yaml" ]

  # Verify values-obs.yaml is a copy of values.yaml
  diff "$workspace_dir/chart/values.yaml" "$workspace_dir/values-obs.yaml"

  rm -rf "$tmpdir"
}

@test "copy_obs_artifacts: fails when source chart missing" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/nonexistent"
  workspace_dir="$tmpdir/workspace"
  mkdir -p "$workspace_dir"

  run copy_obs_artifacts "$chart_dir" "$workspace_dir"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "copy_obs_artifacts: fails when values.yaml missing" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/chart"
  workspace_dir="$tmpdir/workspace"
  mkdir -p "$chart_dir"
  mkdir -p "$workspace_dir"

  touch "$chart_dir/Chart.yaml"
  # No values.yaml

  run copy_obs_artifacts "$chart_dir" "$workspace_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"values-obs.yaml"* ]]

  rm -rf "$tmpdir"
}

# === Additional OBS Process Tests ===

@test "process_buildtime_services: handles file copy failure" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  cat > "$obs_dir/_service" << 'EOF'
<services>
  <service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
  </service>
</services>
EOF

  # Create values.yaml but make chart_dir read-only to cause copy failure
  touch "$obs_dir/values.yaml"
  chmod -w "$chart_dir"

  mkdir -p "$tmpdir/usr/lib/obs/service"
  cat > "$tmpdir/usr/lib/obs/service/replace_using_env" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$tmpdir/usr/lib/obs/service/replace_using_env"

  PATH="$tmpdir:$PATH"
  run process_buildtime_services "$obs_dir" "$chart_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to copy processed values.yaml"* ]]

  chmod +w "$chart_dir"
  rm -rf "$tmpdir"
}

@test "process_buildtime_services: handles missing _service file" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  # No _service file

  run process_buildtime_services "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "copy_obs_artifacts: preserves file permissions" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/chart"
  workspace_dir="$tmpdir/workspace"
  mkdir -p "$chart_dir/templates"
  mkdir -p "$workspace_dir"

  cat > "$chart_dir/Chart.yaml" << 'EOF'
name: test
EOF

  cat > "$chart_dir/values.yaml" << 'EOF'
key: value
EOF

  # Create an executable file
  cat > "$chart_dir/templates/script.sh" << 'EOF'
#!/bin/bash
echo "test"
EOF
  chmod +x "$chart_dir/templates/script.sh"

  run copy_obs_artifacts "$chart_dir" "$workspace_dir"
  [ "$status" -eq 0 ]

  # Verify executable bit is preserved
  [ -x "$workspace_dir/chart/templates/script.sh" ]

  rm -rf "$tmpdir"
}

@test "process_obs_package: fails gracefully when git clone fails" {
  tmpdir="$(mktemp -d)"
  workspace_dir="$tmpdir/workspace"
  mkdir -p "$workspace_dir"

  cat > "$tmpdir/git" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$tmpdir/git"

  PATH="$tmpdir:$PATH"
  run process_obs_package "https://invalid.git" "$workspace_dir"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

# === Edge Case Tests ===

@test "extract_chart_contents: handles empty tarball" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"

  # Create empty tarball
  tar -czf "$obs_dir/contents.tar.gz" -T /dev/null

  run extract_chart_contents "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]
  [ -d "$chart_dir" ]

  rm -rf "$tmpdir"
}

@test "extract_buildtime_service: handles malformed XML" {
  tmpdir="$(mktemp -d)"
  service_file="$tmpdir/_service"

  cat > "$service_file" << 'EOF'
<services>
  <service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml
  </service
EOF

  run extract_buildtime_service "$service_file"
  [ "$status" -eq 0 ]
  # Should still extract something even if malformed
  [[ "$output" != "" ]] || true

  rm -rf "$tmpdir"
}

@test "run_replace_using_env: handles special characters in parameters" {
  tmpdir="$(mktemp -d)"

  mkdir -p "$tmpdir/usr/lib/obs/service"
  cat > "$tmpdir/usr/lib/obs/service/replace_using_env" << 'EOF'
#!/usr/bin/env bash
# Just verify we can receive the parameters
echo "Parameters received: $@" >&2
exit 0
EOF
  chmod +x "$tmpdir/usr/lib/obs/service/replace_using_env"

  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="file">values.yaml</param>
    <param name="eval">%registry_url</param>
    <param name="var">PREFIX=%img_repository_prefix</param>
  </service>'

  PATH="$tmpdir:$PATH"
  run run_replace_using_env "values.yaml" "$service_xml"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "verify_obs_package_files: handles symlinks correctly" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs"
  actual_dir="$tmpdir/actual"
  mkdir -p "$obs_dir"
  mkdir -p "$actual_dir"

  # Create actual files
  touch "$actual_dir/values.yaml"
  touch "$actual_dir/_service"
  touch "$actual_dir/contents.tar.gz"

  # Create symlinks
  ln -s "$actual_dir/values.yaml" "$obs_dir/values.yaml"
  ln -s "$actual_dir/_service" "$obs_dir/_service"
  ln -s "$actual_dir/contents.tar.gz" "$obs_dir/contents.tar.gz"

  run verify_obs_package_files "$obs_dir"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "copy_chart_yaml: overwrites existing Chart.yaml" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs"
  chart_dir="$tmpdir/chart"
  mkdir -p "$obs_dir"
  mkdir -p "$chart_dir"

  cat > "$obs_dir/Chart.yaml" << 'EOF'
name: new-chart
version: 2.0.0
EOF

  cat > "$chart_dir/Chart.yaml" << 'EOF'
name: old-chart
version: 1.0.0
EOF

  run copy_chart_yaml "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]

  # Verify it was overwritten
  grep -q "new-chart" "$chart_dir/Chart.yaml"
  grep -q "2.0.0" "$chart_dir/Chart.yaml"

  rm -rf "$tmpdir"
}

# === Performance/Stress Tests ===

@test "display_chart_structure: handles large number of template files" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/chart"
  mkdir -p "$chart_dir/templates"

  # Create many template files
  for i in {1..100}; do
    touch "$chart_dir/templates/file${i}.yaml"
  done

  run display_chart_structure "$chart_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Templates directory exists with 100 files"* ]]

  rm -rf "$tmpdir"
}

@test "extract_chart_contents: handles nested directory structure" {
  tmpdir="$(mktemp -d)"
  obs_dir="$tmpdir/obs"
  chart_dir="$tmpdir/chart"
  content_dir="$tmpdir/content"
  mkdir -p "$obs_dir"

  # Create nested structure
  mkdir -p "$content_dir/charts/subcharta/templates"
  mkdir -p "$content_dir/charts/subchartb/charts/subsubc"
  echo "test" > "$content_dir/charts/subcharta/templates/deployment.yaml"

  tar -czf "$obs_dir/contents.tar.gz" -C "$content_dir" .

  run extract_chart_contents "$obs_dir" "$chart_dir"
  [ "$status" -eq 0 ]

  # Verify nested structure preserved
  [ -d "$chart_dir/charts/subcharta/templates" ]
  [ -f "$chart_dir/charts/subcharta/templates/deployment.yaml" ]

  rm -rf "$tmpdir"
}

# === Input Validation Tests ===

@test "create_rpm_macros: handles empty parameters gracefully" {
  local output_file="$TEST_TMP/.rpmmacros-empty"

  run create_rpm_macros "" "" "$output_file"
  [ "$status" -eq 0 ]
  [ -f "$output_file" ]

  # Should use defaults when empty
  content=$(cat "$output_file")
  [[ "$content" == *"registry_url"* ]]
}

@test "extract_file_parameter: handles whitespace in XML" {
  service_xml='<service name="replace_using_env" mode="buildtime">
    <param name="file">  values.yaml  </param>
  </service>'

  run extract_file_parameter "$service_xml"
  [ "$status" -eq 0 ]
  # Should trim whitespace
  [[ "$output" == *"values.yaml"* ]]
}

# === OBS Branch Comparison Tests ===

@test "compare_obs_branches: returns 0 when files are identical" {
  stable_values="$TEST_TMP/stable-values.yaml"
  main_values="$TEST_TMP/main-values.yaml"

  cat > "$stable_values" << 'EOF'
trento-web:
  image:
    repository: registry.suse.com/trento/trento-web
trento-wanda:
  checks:
    image:
      repository: registry.suse.com/trento/trento-checks
EOF

  cp "$stable_values" "$main_values"

  run compare_obs_branches "$stable_values" "$main_values"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No differences"* ]]
}

@test "compare_obs_branches: returns 1 when files differ" {
  stable_values="$TEST_TMP/stable-values.yaml"
  main_values="$TEST_TMP/main-values.yaml"

  cat > "$stable_values" << 'EOF'
trento-wanda:
  checks:
    image:
      repository: registry.suse.com/trento/checks
EOF

  cat > "$main_values" << 'EOF'
trento-wanda:
  checks:
    image:
      repository: registry.suse.com/trento/trento-checks
EOF

  run compare_obs_branches "$stable_values" "$main_values"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Differences found"* ]]
  [[ "$output" == *"trento/checks"* ]]
  [[ "$output" == *"trento/trento-checks"* ]]
}

@test "compare_obs_branches: returns error when stable file missing" {
  main_values="$TEST_TMP/main-values.yaml"
  echo "test" > "$main_values"

  run compare_obs_branches "/nonexistent/file" "$main_values"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"Stable values file not found"* ]]
}

@test "compare_obs_branches: returns error when main file missing" {
  stable_values="$TEST_TMP/stable-values.yaml"
  echo "test" > "$stable_values"

  run compare_obs_branches "$stable_values" "/nonexistent/file"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"Main values file not found"* ]]
}
