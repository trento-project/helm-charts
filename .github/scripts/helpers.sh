#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

# Shared utilities for CVE scanning and remediation workflows
set -euo pipefail

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
log_info() { echo "ℹ️  $*" >&2; }
log_success() { echo "✅ $*" >&2; }
log_error() { echo "❌ $*" >&2; }
log_warning() { echo "⚠️  $*" >&2; }

# === IMAGE SANITIZATION ===
# Sanitize image name for use in filenames and IDs
# Uses consistent MD5 hashing for deterministic output
sanitize_image_name() {
  local image="$1"
  echo -n "$image" | md5sum | cut -c1-12
}

# Extract base image name (registry + repo, no tag/version)
get_image_base_name() {
  local image="$1"
  echo "$image" | sed -E 's/:.*//; s/[^a-zA-Z0-9-]/-/g'
}

# === HELM OPERATIONS ===
# Setup Helm repositories from Chart.yaml dependencies
setup_helm_repos() {
  local chart_path="$1"

  log_info "Setting up Helm repositories"

  if ! grep -q "repository: http" "$chart_path/Chart.yaml" 2>/dev/null; then
    log_info "No external Helm repositories found"
    return 0
  fi

  grep "repository: http" "$chart_path/Chart.yaml" \
    | sed 's/.*repository: //' \
    | sort -u \
    | while read -r repo_url; do
      # shellcheck disable=SC2155
      local repo_name="repo-$(echo "$repo_url" | md5sum | cut -c1-8)"
      if ! helm repo add "$repo_name" "$repo_url" >/dev/null 2>&1; then
        log_warning "Failed to add Helm repo: $repo_url"
      fi
    done

  return 0
}

# Build Helm dependencies
build_helm_deps() {
  local chart_path="$1"

  log_info "Building Helm dependencies for $chart_path"
  if ! helm dependency build "$chart_path" --skip-refresh 2>&1 | grep -v "^WARNING" > /dev/null; then
    log_error "Failed to build Helm dependencies"
    return 1
  fi

  log_success "Helm dependencies built"
  return 0
}

# === IMAGE EXTRACTION ===
# Extract all images from Helm chart template
extract_images_from_chart() {
  local chart_path="$1"

  helm template trento "$chart_path" "${HELM_TEMPLATE_FLAGS[@]}" 2>/dev/null \
    | grep -E "^\s+image:" \
    | awk '{gsub(/"/, "", $2); print $2}' \
    | sort -u
}

# Extract images and output as JSON array (for GitHub Actions matrix)
extract_images_json() {
  local chart_path="$1"

  extract_images_from_chart "$chart_path" | jq -R . | jq -s -c .
}

# Complete extraction pipeline: setup repos, build deps, extract images
# Returns JSON array of images
extract_all_images() {
  local chart_path="$1"

  setup_helm_repos "$chart_path" || return 1
  build_helm_deps "$chart_path" || return 1
  extract_images_json "$chart_path"
}

# === GIT OPERATIONS ===
# Safely checkout a different branch, stashing changes if needed
safe_git_checkout() {
  local target_ref="$1"
  local stash_name="cve-scan-tmp"

  local has_changes=0
  if ! git diff --quiet; then
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

# Restore from git stash after checkout
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

# === JSON OPERATIONS ===
# Validate and pretty-print JSON
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
# Parse version and suffix from tag
# Input: tag (e.g., "3.12.6-management-alpine" or "v3.12.6")
# Output: "3.12.6|−management-alpine"
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

# Validate if a tag is a valid semantic version using semver-tool
is_valid_semver() {
  local tag="$1"
  local version="${tag#v}"

  # Use semver --coerce to normalize to X.Y.Z format
  local coerced
  coerced=$(semver --coerce "$version" 2>/dev/null)

  [ -n "$coerced" ]
}

# Coerce tag to X.Y.Z format using semver binary
coerce_to_semver() {
  local tag="$1"
  local version="${tag#v}"

  semver --coerce "$version" 2>/dev/null || echo "$version"
}

# Compare two semantic versions using semver tool
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
compare_semver() {
  local v1="$1"
  local v2="$2"

  if [[ -z "$v1" || -z "$v2" ]]; then
    return 0
  fi

  local sorted
  sorted=$(semver --coerce "$v1" "$v2" 2>/dev/null)

  local lowest
  lowest=$(echo "$sorted" | head -1)

  if [ "$lowest" = "$v1" ]; then
    if [ "$v1" = "$v2" ]; then
      return 0  # equal
    else
      return 2  # v1 < v2
    fi
  else
    return 1  # v1 > v2
  fi
}

# List all tags for a container image (newest first)
list_image_tags() {
  local image_ref="$1"

  if ! skopeo list-tags "docker://${image_ref}" 2>/dev/null \
       | jq -r '.Tags[]' \
       | while read -r tag; do
         if is_valid_semver "$tag"; then
           echo "$tag"
         fi
       done \
       | sort -V -r; then
    log_warning "Failed to list tags for $image_ref"
    return 1
  fi

  return 0
}

# === CLEANUP & WORKFLOW HELPERS ===

# Global for trap cleanup
_trap_cleanup_files=()

# Cleanup temp files on trap
_cleanup_on_trap() {
  rm -f "${_trap_cleanup_files[@]}" 2>/dev/null || true
}

# Setup trap for automatic temp file cleanup
# Usage: trap_cleanup file1 file2 ...
trap_cleanup() {
  _trap_cleanup_files=("$@")
  trap _cleanup_on_trap EXIT INT TERM
}

# Write to GITHUB_OUTPUT if it exists
# Usage: github_output "key" "value"
github_output() {
  local key="$1"
  local value="$2"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${key}=${value}" >> "$GITHUB_OUTPUT"
  fi
}

# Validate target tag is not null or empty
# Usage: validate_target_tag "$target_tag"
# Returns: 0 if valid, 1 if invalid
validate_target_tag() {
  local target_tag="$1"

  if [ -z "$target_tag" ] || [ "$target_tag" = "null" ]; then
    log_error "No target tag in upgrade plan"
    return 1
  fi

  return 0
}
