#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CHART_DIR="${CHART_DIR:-charts/trento-server}"
TRENTO_NAMESPACE="${TRENTO_NAMESPACE:-trento}"

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

# === Kubernetes Diagnostics ===

# Display status of all pods and highlight non-running pods.
# Uses: TRENTO_NAMESPACE environment variable
# Outputs: Pod status information
show_pods_status() {
  section "=== All pods ==="
  kubectl get pods -n "$TRENTO_NAMESPACE" -o wide

  section "=== Pods not running ==="
  kubectl get pods -n "$TRENTO_NAMESPACE" --field-selector=status.phase!=Running -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason 2>/dev/null || echo "✅ All pods running"
}

# Display Kubernetes events for the namespace.
# Args: $1 (string, optional) - If set, show all events; otherwise recent events
#       $2 (string, optional) - Number of recent events to show (default: 30)
# Uses: TRENTO_NAMESPACE environment variable
# Outputs: Kubernetes events
show_events() {
  local sort_by="${1:-}"
  local limit="${2:-30}"

  if [ -z "$sort_by" ]; then
    section "=== Recent events (last $limit) ==="
    kubectl get events -n "$TRENTO_NAMESPACE" --sort-by='.lastTimestamp' | tail -"$limit"
  else
    section "=== All events ==="
    kubectl get events -n "$TRENTO_NAMESPACE" --sort-by='.lastTimestamp'
  fi
}

# Display logs from all pods in the namespace.
# Args: $1 (string, optional) - Number of log lines per pod (default: 30, 0 for all)
#       $2 (string, optional) - Context prefix for section header (e.g., "Recent ")
#       $3 (string, optional) - Whether to show previous container logs (default: false)
#       $4 (string, optional) - Custom separator line
# Uses: TRENTO_NAMESPACE environment variable
# Outputs: Pod logs for each container
show_pod_logs() {
  local log_lines="${1:-30}"
  local log_context="${2:-}"
  local show_previous="${3:-false}"
  local separator="${4:-────────────────────────────────────────────────────────────────────────}"

  section "=== ${log_context}Pod logs (last $log_lines lines each) ==="
  local pod
  for pod in $(kubectl get pods -n "$TRENTO_NAMESPACE" -o jsonpath='{.items[*].metadata.name}'); do
    echo ""
    echo "$separator"
    echo "Pod: $pod"
    echo "$separator"
    kubectl logs -n "$TRENTO_NAMESPACE" "$pod" --all-containers=true --tail="$log_lines" --ignore-errors=true || echo "No logs available"

    if [ "$show_previous" = "true" ]; then
      echo ""
      echo "--- $pod (previous) ---"
      kubectl logs -n "$TRENTO_NAMESPACE" "$pod" --all-containers=true --previous --ignore-errors=true 2>/dev/null || echo "No previous logs"
    fi
  done
}

# Display logs only from failed or pending pods.
# Uses: TRENTO_NAMESPACE environment variable
# Outputs: Logs from non-running pods (last 100 lines each)
show_failed_pod_logs() {
  section "=== Logs for failed/pending pods ==="
  local failed_pods
  failed_pods=$(kubectl get pods -n "$TRENTO_NAMESPACE" --field-selector=status.phase!=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [ -n "$failed_pods" ]; then
    for pod in $failed_pods; do
      echo ""
      echo "────────────────────────────────────────────────────────────────────────"
      echo "Pod: $pod (last 100 lines)"
      echo "────────────────────────────────────────────────────────────────────────"
      kubectl logs -n "$TRENTO_NAMESPACE" "$pod" --all-containers=true --tail=100 --ignore-errors=true || echo "No logs available"
    done
  else
    echo "✅ No failed or pending pods"
  fi
}

# === Diagnostic Suites ===

# Run post-installation diagnostic checks.
# Outputs: Pod status, events, and failed pod logs
post_install_diagnostics() {
  banner "                      POST-INSTALL DIAGNOSTICS                          "
  show_pods_status
  show_events
  show_failed_pod_logs
  echo ""
  banner "                      DIAGNOSTICS COMPLETE                              "
}

# === Version Comparison ===

# Compare container image versions between two files and display differences.
# Args: $1 (string) - Path to current images file (format: chart|name|type|image:tag)
#       $2 (string) - Path to new images file (format: chart|image:tag)
# Outputs: Formatted comparison showing version changes, new images, and unchanged images
compare_versions() {
  local current_images_file="$1"
  local new_images_file="$2"

  echo ""
  banner "                    CONTAINER VERSION COMPARISON                        "
  echo ""

  local current_chart=""
  local chart_name img_full img_registry img_name img_tag old_line old_full old_registry old_tag

  while IFS='|' read -r chart_name img_full; do
    img_registry=$(echo "$img_full" | sed -E 's|/.*||')
    img_name=$(echo "$img_full" | sed -E 's|.*/||; s|:.*||')
    img_tag=$(echo "$img_full" | sed -E 's|.*:||')

    if [ "$chart_name" != "$current_chart" ]; then
      if [ -n "$current_chart" ]; then echo ""; fi
      echo "📦 Chart: ${chart_name}"
      echo "────────────────────────────────────────────────────────────────────────"
      current_chart="$chart_name"
    fi

    old_line=$(grep "|[^|]*|[^|]*|[^|]*/${img_name}:" "$current_images_file" | head -1 || true)

    if [ -n "$old_line" ]; then
      old_full=$(echo "$old_line" | cut -d'|' -f4)
      old_registry=$(echo "$old_full" | sed -E 's|/.*||')
      old_tag=$(echo "$old_full" | sed -E 's|.*:||')

      if [ "$old_tag" != "$img_tag" ] || [ "$old_registry" != "$img_registry" ]; then
        echo -n "  🔄 ${img_name}: "

        if [ "$old_registry" != "$img_registry" ]; then
          echo -n "${old_registry}→${img_registry} "
        fi

        if [ "$old_tag" != "$img_tag" ]; then
          echo "${old_tag} → ${img_tag}"
        else
          echo "${img_tag}"
        fi
      else
        echo "  ✅ ${img_name}: ${img_tag}"
      fi
    else
      echo "  🆕 ${img_name}: ${img_tag} (new)"
    fi
  done < "$new_images_file"

  echo ""
  echo "────────────────────────────────────────────────────────────────────────"
}

# Extract and compare container versions between deployed pods and Helm chart.
# Uses: TRENTO_NAMESPACE, CHART_DIR, HELM_COMMON_FLAGS environment variables
# Outputs: Comparison of current vs new container image versions
compare_container_versions() {
  local tmp_current_images
  local tmp_new_images
  local tmp_new_images_raw

  tmp_current_images=$(mktemp)
  tmp_new_images=$(mktemp)
  tmp_new_images_raw=$(mktemp)

  section "=== Extracting current deployed images ==="
  kubectl get pods -n "$TRENTO_NAMESPACE" -o json | \
    jq -r '
      .items[] |
      .metadata.labels."app.kubernetes.io/name" as $chart |
      (
        ((.spec.initContainers // [])[] |
        "\($chart)|\(.name)|init|\(.image)"),
        ((.spec.containers // [])[] |
        "\($chart)|\(.name)|container|\(.image)")
      )
    ' | sort > "$tmp_current_images"

  echo "Current images found:"
  cat "$tmp_current_images"

  section "=== Extracting new chart images ==="
  helm template trento "$CHART_DIR" \
    $HELM_COMMON_FLAGS | \
    grep -E "^\s+image:" | \
    awk '{gsub(/"/, "", $2); print $2}' | \
    sort -u > "$tmp_new_images_raw"

  local chart_dir chart_name display_name
  for chart_dir in "$CHART_DIR"/charts/*/; do
    if [ -d "$chart_dir" ]; then
      chart_name=$(basename "$chart_dir")
      display_name=$(echo "$chart_name" | sed 's/^trento-//')

      helm template trento "$CHART_DIR" \
        $HELM_COMMON_FLAGS \
        -s "charts/${chart_name}/templates/*.yaml" 2>/dev/null | \
        grep -E "^\s+image:" | \
        awk -v chart="$display_name" '{gsub(/"/, "", $2); print chart "|" $2}' >> "$tmp_new_images" || true
    fi
  done

  local img
  while read -r img; do
    if ! grep -q "|${img}$" "$tmp_new_images"; then
      echo "main|${img}" >> "$tmp_new_images"
    fi
  done < "$tmp_new_images_raw"

  sort -u "$tmp_new_images" -o "$tmp_new_images"

  echo "New images found:"
  cat "$tmp_new_images"

  compare_versions "$tmp_current_images" "$tmp_new_images"
}


# === API Testing ===

# Verify API functionality through ingress endpoint.
# Uses: TRENTO_NAMESPACE, TRENTO_WEB_ORIGIN, REPO_ROOT environment variables
# Outputs: API test results and certificate information
verify_api() {
  banner "                         API FUNCTIONALITY TEST                         "
  echo ""
  section "=== Testing Trento API endpoints via ingress ==="

  local ingress_host="${TRENTO_WEB_ORIGIN:-trento-test.local}"
  local ingress_ip
  ingress_ip=$(kubectl get ingress -n "$TRENTO_NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

  if [ -n "$ingress_ip" ]; then
    echo "Ingress IP: $ingress_ip"
    echo "Adding $ingress_ip $ingress_host to /etc/hosts"
    echo "$ingress_ip $ingress_host" | sudo tee -a /etc/hosts > /dev/null
  else
    echo "Using ingress hostname: $ingress_host"
  fi

  section "=== cert-manager checks ==="

  echo "[TLS] Recent CertificateRequests (ns: ${TRENTO_NAMESPACE}):"
  kubectl get certificaterequest -n "$TRENTO_NAMESPACE" --sort-by='.metadata.creationTimestamp' -o wide 2>/dev/null || echo "No CertificateRequests found"

  INGRESS_HOST="$ingress_host" \
    bash "$REPO_ROOT/.github/scripts/helm-upgrade-smoke-test.sh"
}

# Display logs from web pod init container (database migrations).
# Uses: TRENTO_NAMESPACE environment variable
# Outputs: Init container logs for web pod
show_web_init_logs() {
  section "=== Web init container logs (DB migration) ==="
  local web_pod
  web_pod=$(kubectl get pod -n "$TRENTO_NAMESPACE" \
    -l "app.kubernetes.io/name=web,app.kubernetes.io/instance=trento-server" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$web_pod" ]; then
    kubectl logs "$web_pod" -n "$TRENTO_NAMESPACE" -c init || echo "Failed to get web init logs"
  else
    echo "Failed to find web pod"
  fi
}

# Run post-upgrade diagnostic checks.
# Outputs: Pod status, events, web init logs, and recent pod logs
post_upgrade_diagnostics() {
  banner "                         POST-UPGRADE DIAGNOSTICS                       "
  show_pods_status
  show_events
  show_web_init_logs
  show_pod_logs 50 "Recent "
  echo ""
  banner "                      DIAGNOSTICS COMPLETE                              "
}

# Run comprehensive failure diagnostics with full logs.
# Outputs: Pod status, all events, and full pod logs including previous containers
failure_diagnostics() {
  banner "                    FAILURE DIAGNOSTICS - FULL LOGS                     "
  echo ""
  show_pods_status
  show_events "all"
  show_pod_logs 0 "Full " true "════════════════════════════════════════════════════════════════════════"
}

main() {
  case "${1:-}" in
    post-install-diagnostics)
      post_install_diagnostics
      ;;
    compare-container-versions)
      compare_container_versions
      ;;
    post-upgrade-diagnostics)
      post_upgrade_diagnostics
      ;;
    verify-api)
      verify_api
      ;;
    failure-diagnostics)
      failure_diagnostics
      ;;
    *)
      printf '%s\n' "Usage: upgrade-test.sh <command>" >&2
      printf '%s\n' "" >&2
      printf '%s\n' "Commands:" >&2
      printf '%s\n' "  post-install-diagnostics" >&2
      printf '%s\n' "  compare-container-versions" >&2
      printf '%s\n' "  post-upgrade-diagnostics" >&2
      printf '%s\n' "  verify-api" >&2
      printf '%s\n' "  failure-diagnostics" >&2
      exit 1
      ;;
  esac
}

main "$@"
