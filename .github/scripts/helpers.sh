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

# === HELM OPERATIONS ===
# Setup Helm repositories from Chart.yaml dependencies
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

# Build Helm dependencies
build_helm_deps() {
  local chart_path="$1"

  log_info "Building Helm dependencies for $chart_path"
  local output
  if ! output=$(helm dependency build "$chart_path" --skip-refresh 2>&1); then
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

# === GIT OPERATIONS ===
# Safely checkout a different branch, stashing changes if needed
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
