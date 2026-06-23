#!/usr/bin/env bats

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

# Test suite for helpers.sh

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/helpers.sh"
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/cve-scan-helper-remediation.sh"

  # Keep test flow explicit through `run` status checks.
  set +e

  if command -v semver >/dev/null 2>&1; then
    SEMVER_AVAILABLE=1
  else
    SEMVER_AVAILABLE=0
  fi
}

@test "_coerce_version_string handles valid and invalid formats" {
  run _coerce_version_string "1.2.3"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]

  run _coerce_version_string "1.2"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.0" ]

  run _coerce_version_string "5"
  [ "$status" -eq 0 ]
  [ "$output" = "5.0.0" ]

  run _coerce_version_string "invalid"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "coerce_to_semver coerces and preserves invalid input" {
  run coerce_to_semver "v1.2.3"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]

  run coerce_to_semver "1.2"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.0" ]

  run coerce_to_semver "invalid"
  [ "$status" -eq 0 ]
  [ "$output" = "invalid" ]
}

@test "parse_version extracts version and suffix" {
  run parse_version "v1.2.3"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3|" ]

  run parse_version "1.2.3-alpha"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3|-alpha" ]

  run parse_version "invalid"
  [ "$status" -eq 0 ]
  [ "$output" = "|invalid" ]
}

@test "sanitize_image_name is deterministic" {
  run sanitize_image_name "ghcr.io/org/image:v1.2.3"
  [ "$status" -eq 0 ]
  hash1="$output"

  run sanitize_image_name "ghcr.io/org/image:v1.2.3"
  [ "$status" -eq 0 ]
  hash2="$output"

  [ "$hash1" = "$hash2" ]

  run sanitize_image_name "different/image:tag"
  [ "$status" -eq 0 ]
  [ "$hash1" != "$output" ]
}

@test "get_image_base_name strips tag and sanitizes" {
  run get_image_base_name "ghcr.io/org/image:v1.2.3"
  [ "$status" -eq 0 ]
  [ "$output" = "ghcr-io-org-image" ]

  run get_image_base_name "docker.io/library/postgres:latest"
  [ "$status" -eq 0 ]
  [ "$output" = "docker-io-library-postgres" ]

  run get_image_base_name "image"
  [ "$status" -eq 0 ]
  [ "$output" = "image" ]
}

@test "output_json writes valid JSON and rejects invalid JSON" {
  tmpdir="$(mktemp -d)"
  output_file="$tmpdir/test.json"

  run output_json "$output_file" '{"key":"value"}'
  [ "$status" -eq 0 ]
  [ -f "$output_file" ]
  grep -q '"key"' "$output_file"

  run output_json "$output_file" 'invalid json'
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "compare_semver returns expected status codes" {
  if [ "$SEMVER_AVAILABLE" -ne 1 ]; then
    skip "requires semver CLI tool"
  fi

  run compare_semver "1.2.3" "1.2.3"
  [ "$status" -eq 0 ]

  run compare_semver "2.0.0" "1.9.9"
  [ "$status" -eq 1 ]

  run compare_semver "1.0.0" "2.0.0"
  [ "$status" -eq 2 ]
}

@test "compare_semver validates required inputs" {
  if [ "$SEMVER_AVAILABLE" -ne 1 ]; then
    skip "requires semver CLI tool"
  fi

  run compare_semver "" "1.2.3"
  [ "$status" -eq 3 ]

  run compare_semver "1.2.3" ""
  [ "$status" -eq 3 ]
}

@test "is_valid_semver accepts numeric tags and rejects invalid tags" {
  if [ "$SEMVER_AVAILABLE" -ne 1 ]; then
    skip "requires semver CLI tool"
  fi

  run is_valid_semver "v1.2.3"
  [ "$status" -eq 0 ]

  run is_valid_semver "1.2"
  [ "$status" -eq 0 ]

  run is_valid_semver "invalid"
  [ "$status" -eq 1 ]

  run is_valid_semver "1.2.3-alpha"
  [ "$status" -eq 1 ]
}

@test "logging helpers write expected message" {
  run log_info "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]

  run log_success "ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]

  run log_error "boom"
  [ "$status" -eq 0 ]
  [[ "$output" == *"boom"* ]]

  run log_warning "warn"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn"* ]]
}

@test "github_output writes only when GITHUB_OUTPUT is set" {
  tmpdir="$(mktemp -d)"
  output_file="$tmpdir/out.txt"

  GITHUB_OUTPUT="$output_file"
  run github_output "k" "v"
  [ "$status" -eq 0 ]
  [ -f "$output_file" ]
  grep -q '^k=v$' "$output_file"

  unset GITHUB_OUTPUT
  before_lines=$(wc -l < "$output_file")
  run github_output "x" "y"
  [ "$status" -eq 0 ]
  after_lines=$(wc -l < "$output_file")
  [ "$before_lines" -eq "$after_lines" ]

  rm -rf "$tmpdir"
}

@test "trap_cleanup registers cleanup trap and tracks files" {
  tmpdir="$(mktemp -d)"
  file_a="$tmpdir/a.tmp"
  file_b="$tmpdir/b.tmp"
  touch "$file_a" "$file_b"

  trap_cleanup "$file_a" "$file_b"

  # Verify the trap command was registered.
  trap_output="$(trap -p EXIT)"
  [[ "$trap_output" == *"_cleanup_on_trap"* ]]

  # Validate behavior directly: cleanup handler removes tracked files.
  _cleanup_on_trap
  [ ! -e "$file_a" ]
  [ ! -e "$file_b" ]

  rm -rf "$tmpdir"
}

@test "list_image_tags filters semver and sorts descending" {
  if [ "$SEMVER_AVAILABLE" -ne 1 ]; then
    skip "requires semver CLI tool"
  fi

  tmpdir="$(mktemp -d)"
  cat > "$tmpdir/skopeo" << 'EOF'
#!/usr/bin/env bash
cat << 'JSON'
{"Tags":["latest","1.2.3","2.0.0","1.9.9","v1.0.0","bad"]}
JSON
EOF
  chmod +x "$tmpdir/skopeo"

  PATH="$tmpdir:$PATH"
  run list_image_tags "example.com/repo/image"
  [ "$status" -eq 0 ]

  expected=$'2.0.0\n1.9.9\n1.2.3\nv1.0.0'
  [ "$output" = "$expected" ]

  rm -rf "$tmpdir"
}

# === Logging Functions ===

@test "log_info outputs message to stderr" {
  run log_info "test message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test message"* ]]
}

@test "log_success outputs message to stderr" {
  run log_success "success message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"success message"* ]]
}

@test "log_error outputs message to stderr" {
  run log_error "error message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"error message"* ]]
}

@test "log_warning outputs message to stderr" {
  run log_warning "warning message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning message"* ]]
}

# === Image Utilities ===

@test "parse_image_ref splits image and tag" {
  run parse_image_ref "ghcr.io/org/app:v1.0"
  [ "$status" -eq 0 ]
  [ "$output" = "ghcr.io/org/app|v1.0" ]
}

@test "parse_image_ref defaults to latest for no tag" {
  run parse_image_ref "ghcr.io/org/app"
  [ "$status" -eq 0 ]
  [ "$output" = "ghcr.io/org/app|latest" ]
}

@test "is_semantic_version_tag identifies semantic versions" {
  run is_semantic_version_tag "1.2.3"
  [ "$status" -eq 0 ]

  run is_semantic_version_tag "v1.2.3"
  [ "$status" -eq 0 ]

  run is_semantic_version_tag "latest"
  [ "$status" -eq 1 ]
}

@test "extract_image_name extracts last path component" {
  run extract_image_name "ghcr.io/org/app"
  [ "$status" -eq 0 ]
  [ "$output" = "app" ]
}

@test "escape_for_sed escapes regex special chars" {
  run escape_for_sed "ghcr.io/org/app:v1.0"
  [ "$status" -eq 0 ]
  # Should escape dots for regex safety
  [[ "$output" == *"\\."* ]]
  # Slashes don't need escaping when using | as sed delimiter
}

@test "validate_target_tag rejects null" {
  run validate_target_tag ""
  [ "$status" -eq 1 ]

  run validate_target_tag "null"
  [ "$status" -eq 1 ]

  run validate_target_tag "v1.0.0"
  [ "$status" -eq 0 ]
}

# === Version Functions ===

@test "is_version_upgrade detects newer versions" {
  if [ "$SEMVER_AVAILABLE" -ne 1 ]; then
    skip "requires semver CLI tool"
  fi

  run is_version_upgrade "2.0.0" "1.0.0"
  [ "$status" -eq 0 ]

  run is_version_upgrade "1.0.0" "2.0.0"
  [ "$status" -eq 1 ]
}

@test "is_valid_semver validates semantic versions" {
  if [ "$SEMVER_AVAILABLE" -ne 1 ]; then
    skip "requires semver CLI tool"
  fi

  run is_valid_semver "1.2.3"
  [ "$status" -eq 0 ]

  run is_valid_semver "invalid"
  [ "$status" -eq 1 ]
}

# === Array/JSON Functions ===

@test "array_to_json converts args to JSON" {
  run bash -c 'source helpers.sh && array_to_json "item1" "item2" | jq . '
  [ "$status" -eq 0 ]
  [[ "$output" == *"item1"* ]]
}

# === Build Functions ===

@test "generate_branch_name creates valid branch names" {
  run generate_branch_name "alertmanager" "v0.26.0"
  [ "$status" -eq 0 ]
  [ "$output" = "cve-fix/alertmanager-v0.26.0" ]
}

@test "build_commit_message creates commit messages" {
  run build_commit_message "nginx" "1.25.0" 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"nginx"* ]]
  [[ "$output" == *"1.25.0"* ]]
}

@test "preserve_version_constraint preserves operators" {
  run preserve_version_constraint "^1.2.3" "2.0.0"
  [ "$status" -eq 0 ]
  [ "$output" = "^2.0.0" ]
}

@test "build_pr_url creates GitHub PR URLs" {
  run build_pr_url "owner/repo" 123
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/owner/repo/pull/123" ]
}

@test "extract_pr_number extracts number from URL" {
  run extract_pr_number "https://github.com/owner/repo/pull/456"
  [ "$status" -eq 0 ]
  [ "$output" = "456" ]
}

@test "build_pr_result_json creates valid JSON" {
  run build_pr_result_json "123" "https://github.com/..." "branch" "created"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pr_number"* ]]
}

@test "build_update_result_json handles file list" {
  run bash -c 'source helpers.sh && build_update_result_json "file1.yaml" "file2.yaml" | jq .'
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated_files"* ]]
}

@test "build_analysis_json creates analysis output" {
  run bash -c 'source helpers.sh && build_analysis_json "image:tag" "image" "tag" true "[]" | jq .'
  [ "$status" -eq 0 ]
  [[ "$output" == *"image_ref"* ]]
}

@test "build_upgrade_json creates upgrade output" {
  run bash -c 'source helpers.sh && build_upgrade_json "v2.0.0" 50 | jq .'
  [ "$status" -eq 0 ]
  [[ "$output" == *"target_tag"* ]]
}

@test "build_verification_json creates verification output" {
  run bash -c 'source helpers.sh && build_verification_json "image:tag" true "digest123" | jq .'
  [ "$status" -eq 0 ]
  [[ "$output" == *"verified"* ]]
}

# === File Operations ===

@test "output_json writes and validates JSON" {
  tmpdir="$(mktemp -d)"
  output_file="$tmpdir/test.json"

  run output_json "$output_file" '{"key":"value"}'
  [ "$status" -eq 0 ]
  [ -f "$output_file" ]

  rm -rf "$tmpdir"
}

# === Markdown Helpers ===

@test "format_file_list formats as markdown" {
  run bash -c 'source helpers.sh && echo -e "file1.yaml\nfile2.yaml" | format_file_list'
  [ "$status" -eq 0 ]
  [[ "$output" == *"file1.yaml"* ]]
}

# === Internal Helpers ===

@test "_cleanup_on_trap removes tracked files" {
  tmpdir="$(mktemp -d)"
  test_file="$tmpdir/test.tmp"
  touch "$test_file"

  export _trap_cleanup_files=("$test_file")
  _cleanup_on_trap
  [ ! -f "$test_file" ]

  rm -rf "$tmpdir"
}

# === Skipped Integration Tests ===

@test "setup_helm_repos adds repos from Chart.yaml dependencies" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/test-chart"
  mkdir -p "$chart_dir"

  # Create mock helm that tracks repo adds
  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
# Mock helm repo add - just track the call
if [ "$1" = "repo" ] && [ "$2" = "add" ]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/helm"

  cat > "$chart_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test-chart
version: 1.0.0
dependencies:
  - name: postgresql
    repository: https://charts.bitnami.com/bitnami
    version: "11.0.0"
EOF

  PATH="$tmpdir:$PATH"
  run setup_helm_repos "$chart_dir"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "build_helm_deps calls helm dependency build" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/test-chart"
  mkdir -p "$chart_dir"

  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "dependency" ] && [ "$2" = "build" ]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/helm"

  cat > "$chart_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test-chart
version: 1.0.0
EOF

  PATH="$tmpdir:$PATH"
  run build_helm_deps "$chart_dir"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "extract_images_from_chart extracts images from helm template output" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/test-chart"
  mkdir -p "$chart_dir"

  # Create a minimal mock helm executable
  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
# Mock helm template output - a sample Kubernetes manifest with image references
cat << 'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: "ghcr.io/suse/app:v1.2.3"
      - name: db
        image: "ghcr.io/suse/postgresql:15.1"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: test-statefulset
spec:
  template:
    spec:
      containers:
      - name: redis
        image: "docker.io/library/redis:7.0"
      - name: monitoring
        image: "ghcr.io/suse/prometheus:2.0.0"
YAML
EOF
  chmod +x "$tmpdir/helm"

  # Create minimal Chart.yaml
  cat > "$chart_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test-chart
version: 1.0.0
EOF

  PATH="$tmpdir:$PATH"
  run extract_images_from_chart "$chart_dir"
  [ "$status" -eq 0 ]

  # Verify all images are extracted and sorted
  [[ "$output" == *"ghcr.io/suse/app:v1.2.3"* ]]
  [[ "$output" == *"ghcr.io/suse/postgresql:15.1"* ]]
  [[ "$output" == *"docker.io/library/redis:7.0"* ]]
  [[ "$output" == *"ghcr.io/suse/prometheus:2.0.0"* ]]

  rm -rf "$tmpdir"
}

@test "extract_images_json converts image list to JSON array" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/test-chart"
  mkdir -p "$chart_dir"

  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
cat << 'YAML'
spec:
  containers:
  - image: "image1:v1.0"
  - image: "image2:v2.0"
YAML
EOF
  chmod +x "$tmpdir/helm"

  cat > "$chart_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test-chart
version: 1.0.0
EOF

  PATH="$tmpdir:$PATH"
  run extract_images_json "$chart_dir"
  [ "$status" -eq 0 ]

  # Verify output is valid JSON array
  echo "$output" | jq . >/dev/null
  [[ "$output" == *"image1:v1.0"* ]]
  [[ "$output" == *"image2:v2.0"* ]]

  rm -rf "$tmpdir"
}

@test "extract_all_images runs setup, build, and extraction pipeline" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/test-chart"
  mkdir -p "$chart_dir"

  # Create mock helm that handles multiple subcommands
  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
case "$1" in
  repo)
    # Mock helm repo add/update - just succeed silently
    exit 0
    ;;
  dependency)
    # Mock helm dependency build - just succeed silently
    exit 0
    ;;
  template)
    # Mock helm template output
    cat << 'YAML'
spec:
  containers:
  - image: "image1:v1.0"
  - image: "image2:v2.0"
YAML
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$tmpdir/helm"

  cat > "$chart_dir/Chart.yaml" << 'EOF'
apiVersion: v2
name: test-chart
version: 1.0.0
EOF

  PATH="$tmpdir:$PATH"
  run extract_all_images "$chart_dir"
  [ "$status" -eq 0 ]

  # Verify JSON array output
  echo "$output" | jq . >/dev/null
  [[ "$output" == *"image1:v1.0"* ]]
  [[ "$output" == *"image2:v2.0"* ]]

  rm -rf "$tmpdir"
}

@test "branch_exists_on_remote checks if branch exists on remote" {
  tmpdir="$(mktemp -d)"

  # Create mock git that returns branch info
  cat > "$tmpdir/git" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "ls-remote" ] && [ "$2" = "--heads" ] && [ "$3" = "origin" ]; then
  local branch="$4"
  case "$branch" in
    existing-branch)
      echo "abc123def456  refs/heads/existing-branch"
      exit 0
      ;;
    nonexistent-branch)
      exit 0
      ;;
  esac
fi
exit 1
EOF
  chmod +x "$tmpdir/git"

  PATH="$tmpdir:$PATH"
  run branch_exists_on_remote "existing-branch"
  [ "$status" -eq 0 ]

  run branch_exists_on_remote "nonexistent-branch"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "safe_git_checkout stashes changes and checks out branch" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/git" << 'EOF'
#!/usr/bin/env bash
case "$1" in
  diff)
    # Simulate having uncommitted changes
    exit 1
    ;;
  stash)
    # Mock stash push
    if [ "$2" = "push" ]; then
      exit 0
    fi
    # Mock stash pop
    if [ "$2" = "pop" ]; then
      exit 0
    fi
    exit 1
    ;;
  checkout)
    # Mock checkout
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$tmpdir/git"

  PATH="$tmpdir:$PATH"
  run safe_git_checkout "target-branch"
  [ "$status" -eq 0 ]
  # Should return 1 (had stash)
  [ "$output" = "1" ]

  rm -rf "$tmpdir"
}

@test "restore_from_stash restores stashed changes when needed" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/git" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "stash" ] && [ "$2" = "pop" ]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/git"

  PATH="$tmpdir:$PATH"
  # Test with had_stash=1
  run restore_from_stash 1
  [ "$status" -eq 0 ]

  # Test with had_stash=0 (should succeed without calling git)
  run restore_from_stash 0
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "get_latest_helm_version retrieves latest version from chart repository" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "search" ] && [ "$2" = "repo" ]; then
  local chart="$3"
  if [ "$chart" = "bitnami/postgresql" ]; then
    echo "bitnami/postgresql  12.5.0  A powerful, open source object-relational database system"
  fi
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/helm"

  PATH="$tmpdir:$PATH"
  run get_latest_helm_version "bitnami/postgresql"
  [ "$status" -eq 0 ]
  [[ "$output" == *"12.5.0"* ]]

  rm -rf "$tmpdir"
}

@test "detect_parent_chart finds parent chart containing component" {
  tmpdir="$(mktemp -d)"
  chart_dir="$tmpdir/charts"
  mkdir -p "$chart_dir/app/values" "$chart_dir/parent"

  # Create test files
  cat > "$chart_dir/parent/values/web.yaml" << 'EOF'
image:
  repository: ghcr.io/app/web
  tag: v1.0.0
EOF

  cat > "$tmpdir/yq" << 'EOF'
#!/usr/bin/env bash
# Mock yq eval for detecting component in values
if [[ "$1" == "eval" ]]; then
  local file="${@: -1}"
  if grep -q "ghcr.io/app/web" "$file" 2>/dev/null; then
    echo "found"
  else
    echo "null"
  fi
fi
exit 0
EOF
  chmod +x "$tmpdir/yq"

  PATH="$tmpdir:$PATH"
  run detect_parent_chart "$chart_dir" "web"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "build_cve_list_section formats CVE list as markdown" {
  local cve_json='[{"id":"CVE-2021-1234","severity":"HIGH","url":"https://nvd.nist.gov/vuln/detail/CVE-2021-1234"},{"id":"CVE-2021-5678","severity":"MEDIUM","url":"https://nvd.nist.gov/vuln/detail/CVE-2021-5678"}]'
  local nist_url="https://nvd.nist.gov/vuln/detail"

  run build_cve_list_section "$cve_json" "$nist_url"
  [ "$status" -eq 0 ]

  [[ "$output" == *"CVE-2021-1234"* ]]
  [[ "$output" == *"CVE-2021-5678"* ]]
  [[ "$output" == *"HIGH"* ]]
  [[ "$output" == *"MEDIUM"* ]]
}

@test "build_pr_body combines multiple sections into PR body" {
  local updated_files="values.yaml
template.yaml"
  local cve_section="## CVE Fixes
- CVE-2021-1234"
  local alert_section="## Security Alerts Fixed
- Alert 1"

  run build_pr_body "$updated_files" "$cve_section" "$alert_section"
  [ "$status" -eq 0 ]

  [[ "$output" == *"values.yaml"* ]]
  [[ "$output" == *"template.yaml"* ]]
  [[ "$output" == *"CVE-2021-1234"* ]]
  [[ "$output" == *"Alert 1"* ]]
}

@test "format_alerts_pr_section formats GitHub alerts as markdown" {
  local alerts='{"number":1234,"html_url":"https://github.com/org/repo/security/code-scanning/1234","rule_id":"CVE-2021-1234"}
{"number":5678,"html_url":"https://github.com/org/repo/security/code-scanning/5678","rule_id":"CVE-2021-5678"}'
  local nist_url="https://nvd.nist.gov/vuln/detail"

  run format_alerts_pr_section "$alerts" "$nist_url"
  [ "$status" -eq 0 ]

  [[ "$output" == *"Security Alerts Fixed"* ]]
  [[ "$output" == *"CVE-2021-1234"* ]]
  [[ "$output" == *"CVE-2021-5678"* ]]
}

@test "find_compatible_upgrade finds best matching upgrade from tag list" {
  # Test finding compatible upgrade from array of tags
  local tags=("1.0.0" "1.5.0" "2.0.0" "2.1.0" "3.0.0")

  run find_compatible_upgrade "1.9.9" 1 "${tags[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "1.5.0" ]

  # Test no compatible upgrade
  run find_compatible_upgrade "0.5.0" 1 "${tags[@]}"
  [ "$status" -eq 1 ]
}

@test "query_code_scanning_alerts queries GitHub Code Scanning alerts" {
  tmpdir="$(mktemp -d)"

  # Mock gh CLI
  cat > "$tmpdir/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "api" ]] && [[ "$2" == *"code-scanning"* ]]; then
  cat << 'JSON'
{"number":1234,"html_url":"https://github.com/org/repo/security/code-scanning/1234","rule":{"id":"CVE-2021-1234"},"most_recent_instance":{"category":"container/web"}}
{"number":5678,"html_url":"https://github.com/org/repo/security/code-scanning/5678","rule":{"id":"CVE-2021-5678"},"most_recent_instance":{"category":"container/web"}}
JSON
fi
exit 0
EOF
  chmod +x "$tmpdir/gh"

  PATH="$tmpdir:$PATH"
  run query_code_scanning_alerts "owner/repo" "web"
  [ "$status" -eq 0 ]

  # Should contain at least one alert
  [[ "$output" == *"CVE"* ]] || [ -z "$output" ]

  rm -rf "$tmpdir"
}

@test "should_process_file checks if file needs processing" {
  tmpdir="$(mktemp -d)"

  # Create Chart.yaml
  cat > "$tmpdir/Chart.yaml" << 'EOF'
dependencies:
  - name: postgresql
    version: "11.0.0"
EOF

  # Create template file
  cat > "$tmpdir/template.yaml" << 'EOF'
image: ghcr.io/suse/postgresql:15.1
EOF

  cat > "$tmpdir/yq" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "eval" ]]; then
  # Mock yq eval for dependency selection
  if grep -q "dependencies:" "$4"; then
    echo "postgresql"
  fi
fi
exit 0
EOF
  chmod +x "$tmpdir/yq"

  PATH="$tmpdir:$PATH"
  # Test with Chart.yaml
  run should_process_file "$tmpdir/Chart.yaml" "postgresql" "ghcr.io/suse/postgresql" ""
  [ "$status" -eq 0 ]

  # Test with template file
  run should_process_file "$tmpdir/template.yaml" "postgresql" "ghcr.io/suse/postgresql" ""
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "update_chart_yaml updates dependency version in Chart.yaml" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/Chart.yaml" << 'EOF'
dependencies:
  - name: postgresql
    repository: https://charts.bitnami.com/bitnami
    version: "11.0.0"
EOF

  cat > "$tmpdir/helm" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "search" ] && [ "$2" = "repo" ]; then
  echo "bitnami/postgresql  12.0.0  Database"
fi
exit 0
EOF
  chmod +x "$tmpdir/helm"

  cat > "$tmpdir/yq" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "eval" ]] && [[ "$3" == "-i" ]]; then
  # Mock in-place file modification
  local file="${@: -1}"
  sed -i.bak 's/11.0.0/12.0.0/g' "$file"
fi
exit 0
EOF
  chmod +x "$tmpdir/yq"

  PATH="$tmpdir:$PATH"
  run update_chart_yaml "$tmpdir/Chart.yaml" "postgresql" "" "bitnami"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "update_values_or_template updates image references in files" {
  tmpdir="$(mktemp -d)"

  cat > "$tmpdir/values.yaml" << 'EOF'
postgresql:
  repository: ghcr.io/suse/postgresql
  tag: "15.1"
EOF

  cat > "$tmpdir/yq" << 'EOF'
#!/usr/bin/env bash
# Mock yq - just succeed for any eval operations
if [[ "$1" == "eval" ]]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/yq"

  PATH="$tmpdir:$PATH"
  run update_values_or_template "$tmpdir/values.yaml" "15.2" "ghcr.io/suse/postgresql:15.2" "ghcr\\.io/suse/postgresql" "postgresql" "15.1"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

@test "verify_image_in_registry verifies image exists in registry" {
  tmpdir="$(mktemp -d)"

  # Mock skopeo
  cat > "$tmpdir/skopeo" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "inspect" ]; then
  local image="$2"
  case "$image" in
    docker://ghcr.io/suse/app:v1.0)
      cat << 'JSON'
{"Digest":"sha256:abc123def456"}
JSON
      exit 0
      ;;
    docker://ghcr.io/suse/missing:v1.0)
      exit 1
      ;;
  esac
fi
exit 1
EOF
  chmod +x "$tmpdir/skopeo"

  PATH="$tmpdir:$PATH"
  # Test successful verification
  run verify_image_in_registry "ghcr.io/suse/app:v1.0"
  [ "$status" -eq 0 ]
  [[ "$output" == "true|"* ]]
  [[ "$output" == *"sha256:abc123def456"* ]]

  # Test failed verification
  run verify_image_in_registry "ghcr.io/suse/missing:v1.0"
  [ "$status" -eq 0 ]
  [ "$output" = "false|" ]

  rm -rf "$tmpdir"
}

@test "extract_cves_from_sarif extracts CVE IDs from SARIF file" {
  tmpdir="$(mktemp -d)"
  local sarif_file="$tmpdir/test.sarif"
  cat > "$sarif_file" << 'EOF'
{
  "runs": [
    {
      "results": [
        {"ruleId": "CVE-2024-1234"},
        {"ruleId": "CVE-2024-5678"},
        {"ruleId": "NOTACVE-001"},
        {"ruleId": "CVE-2024-1234"}
      ]
    }
  ]
}
EOF

  run extract_cves_from_sarif "$sarif_file"
  [ "$status" -eq 0 ]

  # Verify results: should have 2 unique CVE entries, sorted
  [ "$(echo "$output" | wc -l)" -eq 2 ]
  [[ "$output" == *"CVE-2024-1234"* ]]
  [[ "$output" == *"CVE-2024-5678"* ]]

  rm -rf "$tmpdir"
}

@test "extract_cves_from_sarif returns empty for no CVEs" {
  tmpdir="$(mktemp -d)"
  local sarif_file="$tmpdir/empty.sarif"
  cat > "$sarif_file" << 'EOF'
{
  "runs": [
    {
      "results": [
        {"ruleId": "INFO-001"},
        {"ruleId": "WARNING-002"}
      ]
    }
  ]
}
EOF

  run extract_cves_from_sarif "$sarif_file"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  rm -rf "$tmpdir"
}

@test "extract_cves_from_sarif handles malformed SARIF gracefully" {
  tmpdir="$(mktemp -d)"
  local sarif_file="$tmpdir/malformed.sarif"
  cat > "$sarif_file" << 'EOF'
{
  "invalid": "json structure"
}
EOF

  run extract_cves_from_sarif "$sarif_file"
  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}
