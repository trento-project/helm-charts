#!/usr/bin/env bats
# SPDX-License-Identifier: Apache-2.0

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/helpers.sh"

  # Keep test flow explicit through `run` status checks.
  set +e

  if command -v /usr/bin/semver >/dev/null 2>&1; then
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
