#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

# Shared utilities for CVE scanning and remediation workflows
set -euo pipefail

# Guard against double-sourcing (readonly declarations fail on re-execution).
[[ -n "${_HELPERS_SH_SOURCED:-}" ]] && return 0
readonly _HELPERS_SH_SOURCED=1

# === CONSTANTS ===
# shellcheck disable=SC2034
readonly DEFAULT_CHART_PATH="charts/trento-server"
readonly HELM_TEMPLATE_FLAGS=(
  "--set" "trento-web.enabled=true"
  "--set" "trento-wanda.enabled=true"
  "--set" "trento-mcp-server.enabled=true"
  "--set" "postgresql.enabled=true"
  "--set" "postgresql.postgresqlDatabase=trento"
  "--set" "postgresql.volumePermissions.enabled=true"
  "--set" "postgresql.metrics.enabled=true"
  "--set" "postgresql.replication.enabled=true"
  "--set" "postgresql.shmVolume.enabled=true"
  "--set" "postgresql.shmVolume.chmod.enabled=true"
  "--set" "prometheus.enabled=true"
  "--set" "prometheus.server.enabled=true"
  "--set" "prometheus.server.auth.type=none"
  "--set" "prometheus.alertmanager.enabled=true"
  "--set" "prometheus.prometheus-pushgateway.enabled=true"
  "--set" "prometheus.configmapReload.prometheus.enabled=true"
  "--set" "prometheus.kube-state-metrics.enabled=true"
  "--set" "prometheus.prometheus-node-exporter.enabled=true"
  "--set" "rabbitmq.enabled=true"
  "--set" "rabbitmq.volumePermissions.enabled=true"
  "--set" "rabbitmq.metrics.enabled=true"
  "--set" "global.rabbitmq.tls.mtls.enabled=true"
  "--set" "global.rabbitmq.tls.mtls.certManager.enabled=true"
)
# shellcheck disable=SC2034
readonly CVE_PR_LABEL="dependencies"
# shellcheck disable=SC2034
readonly NIST_CVE_URL="https://nvd.nist.gov/vuln/detail"

# === LOGGING FUNCTIONS ===

# Print an informational message to stderr.
# Args: $1+ (string) - message text
log_info() { echo "ℹ️  $*" >&2; }

# Print a success message to stderr.
# Args: $1+ (string) - message text
log_success() { echo "✅ $*" >&2; }

# Print an error message to stderr.
# Args: $1+ (string) - message text
log_error() { echo "❌ $*" >&2; }

# Print a warning message to stderr.
# Args: $1+ (string) - message text
log_warning() { echo "⚠️  $*" >&2; }

# === IMAGE UTILITIES ===

# Sanitize image name for use in filenames and IDs using MD5 hash.
# Args: $1 (string) - full image reference to hash
# Outputs: 12-character MD5 hash (deterministic across invocations)
sanitize_image_name() {
  local image="$1"
  echo -n "$image" | md5sum | cut -c1-12
}

# Extract base image name (registry + repo without tag/version).
# Args: $1 (string) - full image reference including optional tag
# Outputs: sanitized base name with non-alphanumeric chars replaced by dashes
get_image_base_name() {
  local image="$1"
  echo "$image" | sed -E 's/:.*//; s/[^a-zA-Z0-9-]/-/g'
}

# Parse image reference into base image and tag.
# Args: $1 (string) - full image reference (e.g., "registry/repo:tag")
# Outputs: "base_image|tag" format
parse_image_ref() {
  local image_ref="$1"
  local base_image tag

  if [[ "$image_ref" == *:* ]]; then
    base_image="${image_ref%:*}"
    tag="${image_ref##*:}"
  else
    base_image="$image_ref"
    tag="latest"
  fi

  echo "$base_image|$tag"
}

# Check if a tag has a valid semantic version.
# Args: $1 (string) - image tag to evaluate
# Returns: 0 if semantic, 1 if not
is_semantic_version_tag() {
  local tag="$1"
  local parsed parsed_version

  parsed=$(parse_version "$tag")
  parsed_version="${parsed%|*}"

  if [[ -z "$parsed_version" ]] || [[ ! "$parsed_version" =~ ^[0-9] ]]; then
    return 1
  fi

  return 0
}

# Extract image name (last component after /).
# Args: $1 (string) - full image reference (e.g., "ghcr.io/org/name:tag")
# Outputs: image name only (e.g., "name" from "ghcr.io/org/name")
extract_image_name() {
  local image_ref="$1"
  echo "${image_ref##*/}"
}

# Convert bash array elements to a JSON array.
# Args: $1+ (string) - zero or more strings to include; reads from stdin if no args given
# Outputs: compact JSON array of the provided strings
array_to_json() {
  if [ $# -eq 0 ]; then
    jq -Rs 'split("\n") | map(select(length > 0))'
  else
    printf '%s\n' "$@" | jq -Rs 'split("\n") | map(select(length > 0))'
  fi
}

# === HELM OPERATIONS ===

# Setup Helm repositories from Chart.yaml dependencies.
# Args: $1 (string) - path to the Helm chart directory
# Returns: 0 on success, 1 on failure
setup_helm_repos() {
  local chart_path="$1"

  log_info "Setting up Helm repositories"

  if ! grep -q "repository: http" "$chart_path/Chart.yaml" 2>/dev/null; then
    log_info "No external Helm repositories found"
    return 0
  fi

  while read -r repo_url; do
    # shellcheck disable=SC2155
    local repo_name="repo-$(echo "$repo_url" | md5sum | cut -c1-8)"
    if ! helm repo add "$repo_name" "$repo_url" >/dev/null 2>&1; then
      log_warning "Failed to add Helm repo: $repo_url"
    fi
  done < <(grep "repository: http" "$chart_path/Chart.yaml" \
    | sed 's/.*repository: //' \
    | sort -u)

  return 0
}

# Build Helm chart dependencies.
# Args: $1 (string) - path to the Helm chart directory
# Returns: 0 on success, 1 on failure
build_helm_deps() {
  local chart_path="$1"

  log_info "Building Helm dependencies for $chart_path"
  if ! helm dependency build "$chart_path" --skip-refresh >/dev/null 2>&1; then
    log_error "Failed to build Helm dependencies"
    return 1
  fi

  log_success "Helm dependencies built"
  return 0
}

# Extract all images from Helm chart template.
# Args: $1 (string) - path to the Helm chart directory
# Outputs: image references (one per line) in sorted order
extract_images_from_chart() {
  local chart_path="$1"

  helm template trento "$chart_path" "${HELM_TEMPLATE_FLAGS[@]}" 2>/dev/null \
    | grep -E "^\s+image:" \
    | awk '{gsub(/"/, "", $2); print $2}' \
    | sort -u
}

# Extract images and output as JSON array (for GitHub Actions matrix).
# Args: $1 (string) - path to the Helm chart directory
# Outputs: compact JSON array of image reference strings
extract_images_json() {
  local chart_path="$1"

  extract_images_from_chart "$chart_path" | jq -R . | jq -s -c .
}

# Complete extraction pipeline: setup repos, build deps, extract images.
# Args: $1 (string) - path to the Helm chart directory
# Returns: 0 on success, 1 on failure
# Outputs: compact JSON array of image reference strings
extract_all_images() {
  local chart_path="$1"

  setup_helm_repos "$chart_path" || return 1
  build_helm_deps "$chart_path" || return 1
  extract_images_json "$chart_path"
}

# === CVE EXTRACTION ===

# Extract CVE IDs from SARIF vulnerability scan results.
# Args: $1 (string) - path to the SARIF file to parse
# Outputs: CVE IDs (one per line), sorted and unique
extract_cves_from_sarif() {
  local sarif_file="$1"
  jq -r '.runs[]? | .results[]? | .ruleId' "$sarif_file" 2>/dev/null | \
    grep -E '^CVE-' | sort -u || echo ""
}

# === GIT OPERATIONS ===

# Safely checkout a different branch, stashing uncommitted changes if present.
# Args: $1 (string) - git ref (branch name, tag, or commit SHA) to checkout
# Returns: 0 on success, 1 on failure
# Outputs: echoes 1 if changes were stashed, 0 if not
safe_git_checkout() {
  local target_ref="$1"
  local stash_name="cve-scan-tmp"

  local has_changes=0
  if ! git diff --quiet || ! git diff --cached --quiet; then
    has_changes=1
    log_info "Stashing local changes"
    if ! git stash push -m "$stash_name" >/dev/null 2>&1; then
      log_error "Failed to stash changes"
      return 1
    fi
  fi

  if ! git checkout "$target_ref" >/dev/null 2>&1; then
    log_error "Failed to checkout $target_ref"
    if [ $has_changes -eq 1 ]; then
      git stash pop >/dev/null 2>&1 || log_warning "Failed to restore stashed changes"
    fi
    return 1
  fi

  echo "$has_changes"
}

# Restore from git stash after checkout (use with safe_git_checkout).
# Args: $1 (int) - result from safe_git_checkout (1 if stashed, 0 if not)
# Returns: 0 on success, 1 on failure
restore_from_stash() {
  local had_stash="$1"

  if [ "$had_stash" -eq 1 ]; then
    log_info "Restoring stashed changes"
    if ! git stash pop >/dev/null 2>&1; then
      log_error "Failed to restore stashed changes"
      return 1
    fi
  fi

  return 0
}

# === JSON UTILITIES ===

# Validate JSON format and write to file with pretty-printing.
# Args: $1 (string) - destination file path to write
#       $2 (string) - JSON string to validate and write
# Returns: 0 on success, 1 on failure
output_json() {
  local file="$1"
  local json="$2"

  if ! echo "$json" | jq . > "$file" 2>/dev/null; then
    log_error "Failed to write JSON to $file"
    return 1
  fi

  log_info "Output: $file"
  return 0
}

# === VERSION COMPARISON ===

# Parse version number and suffix from a tag string.
# Args: $1 (string) - version tag to parse (with or without leading "v")
# Outputs: version|suffix format (e.g., "3.12.6|-management-alpine")
parse_version() {
  local tag="$1"

  # Remove optional 'v' prefix
  tag="${tag#v}"

  # Extract version (major.minor.patch or major.minor or major)
  if [[ "$tag" =~ ^([0-9]+(\.[0-9]+)?(\.[0-9]+)?(\.[0-9]+)?) ]]; then
    local version="${BASH_REMATCH[1]}"
    local suffix="${tag#"$version"}"
    echo "$version|$suffix"
  else
    echo "|$tag"
  fi
}

# Internal helper: coerce version string to X.Y.Z format.
# Args: $1 (string) - version string with 1–3 numeric components
# Outputs: zero-padded X.Y.Z version string, or nothing if the input is not numeric
_coerce_version_string() {
  local version="$1"

  if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "$version"
  elif [[ "$version" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    echo "${version}.0"
  elif [[ "$version" =~ ^([0-9]+)$ ]]; then
    echo "${version}.0.0"
  fi
}

# Validate if a tag is a valid semantic version using semver-tool.
# Args: $1 (string) - version tag to validate (with or without leading "v")
# Returns: 0 if valid semantic version, 1 otherwise
is_valid_semver() {
  local tag="$1"
  local version="${tag#v}"

  local coerced
  coerced=$(_coerce_version_string "$version")
  [[ -z "$coerced" ]] && return 1

  # Validate using semver-tool (must be in PATH)
  semver validate "$coerced" >/dev/null 2>&1
}

# Coerce tag to X.Y.Z semantic version format.
# Args: $1 (string) - version tag to coerce (with or without leading "v")
# Outputs: X.Y.Z version string, or the original tag if it cannot be coerced
coerce_to_semver() {
  local tag="$1"
  local version="${tag#v}"

  local coerced
  coerced=$(_coerce_version_string "$version")
  echo "${coerced:-$version}"
}

# Compare two semantic version strings.
# Args: $1 (string) - first version string (v1)
#       $2 (string) - second version string (v2)
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2, 3 if invalid input
compare_semver() {
  local v1="$1"
  local v2="$2"

  if [[ -z "$v1" || -z "$v2" ]]; then
    log_error "compare_semver requires two non-empty version strings. Got: '$v1' and '$v2'"
    return 3
  fi

  local cv1 cv2 result
  cv1=$(coerce_to_semver "$v1")
  cv2=$(coerce_to_semver "$v2")

  if [ "$cv1" = "$cv2" ]; then
    return 0
  fi

  result=$(semver compare "$cv1" "$cv2" 2>/dev/null)

  if [ "$result" = "-1" ]; then
    return 2  # v1 < v2
  elif [ "$result" = "1" ]; then
    return 1  # v1 > v2
  else
    return 0  # equal
  fi
}

# List all valid semantic version tags for a container image, preserving suffixes.
# Args: $1 (string) - image reference without tag (e.g., "registry/repo")
# Returns: 0 on success, 1 on failure
# Outputs: valid version tags (one per line), newest first
list_image_tags() {
  local image_ref="$1"

  if ! skopeo list-tags "docker://${image_ref}" 2>/dev/null \
       | jq -r '.Tags[]' \
       | while read -r tag; do
         # Parse version and check if numeric prefix is valid
         local parsed parsed_version
         parsed=$(parse_version "$tag")
         parsed_version="${parsed%|*}"

         # Keep tag if it has a valid numeric version prefix
         if [[ -n "$parsed_version" ]] && [[ "$parsed_version" =~ ^[0-9] ]]; then
           echo "$tag"
         fi
       done \
       | sort -V -r; then
    log_warning "Failed to list tags for $image_ref"
    return 1
  fi

  return 0
}

# === WORKFLOW UTILITIES ===

# Global for trap cleanup - array of files to remove on exit
_trap_cleanup_files=()

# Internal helper: remove registered cleanup files on trap signal.
# Reads: _trap_cleanup_files (array) - paths of temporary files to delete, set by trap_cleanup
_cleanup_on_trap() {
  rm -f "${_trap_cleanup_files[@]}" 2>/dev/null || true
}

# Setup trap for automatic temporary file cleanup on exit/interrupt.
# Args: $1+ (string) - paths of temporary files to delete on EXIT, INT, or TERM
trap_cleanup() {
  _trap_cleanup_files=("$@")
  trap _cleanup_on_trap EXIT INT TERM
}

# Write key-value pairs to GitHub Actions output file.
# Args: $1 (string) - output variable name
#       $2 (string) - output variable value
github_output() {
  local key="$1"
  local value="$2"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${key}=${value}" >> "$GITHUB_OUTPUT"
  fi
}
