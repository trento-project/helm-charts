#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CHART_DIR="${CHART_DIR:-charts/trento-server}"
TRENTO_NAMESPACE="${TRENTO_NAMESPACE:-trento}"

section() {
  printf '\n%s\n' "$1"
}

banner() {
  printf '%s\n' "╔════════════════════════════════════════════════════════════════════════╗"
  printf '%s\n' "║$1║"
  printf '%s\n' "╚════════════════════════════════════════════════════════════════════════╝"
}

show_pods_status() {
  section "=== All pods ==="
  kubectl get pods -n "$TRENTO_NAMESPACE" -o wide

  section "=== Pods not running ==="
  kubectl get pods -n "$TRENTO_NAMESPACE" --field-selector=status.phase!=Running -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason 2>/dev/null || echo "✅ All pods running"
}

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

post_install_diagnostics() {
  banner "                      POST-INSTALL DIAGNOSTICS                          "
  show_pods_status
  show_events
  show_failed_pod_logs
  echo ""
  banner "                      DIAGNOSTICS COMPLETE                              "
}

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

post_upgrade_diagnostics() {
  banner "                         POST-UPGRADE DIAGNOSTICS                       "
  show_pods_status
  show_events
  show_web_init_logs
  show_pod_logs 50 "Recent "
  echo ""
  banner "                      DIAGNOSTICS COMPLETE                              "
}

failure_diagnostics() {
  banner "                    FAILURE DIAGNOSTICS - FULL LOGS                     "
  echo ""
  show_pods_status
  show_events "all"
  show_pod_logs 0 "Full " true "════════════════════════════════════════════════════════════════════════"
}

# === OBS Package Processing Functions ===

# Fetch OBS package from git mirror repository.
# Args: $1 (string) - Git source URL to clone from
#       $2 (string) - Working directory path
# Returns: 0 on success, 1 on failure
# Outputs: Path to cloned obs-package directory
fetch_obs_package() {
  local git_url="$1"
  local work_dir="$2"

  echo "Fetching OBS package from ${git_url}..."

  if ! git clone --depth 1 "${git_url}" "${work_dir}/obs-package" 2>/dev/null; then
    echo "ERROR: Failed to clone OBS package from ${git_url}"
    return 1
  fi

  echo "${work_dir}/obs-package"
  return 0
}

# Verify required OBS package files exist.
# Args: $1 (string) - Path to OBS package directory
# Returns: 0 if all required files exist, 1 otherwise
verify_obs_package_files() {
  local obs_dir="$1"
  local required_files=("values.yaml" "_service" "contents.tar.gz")

  for file in "${required_files[@]}"; do
    if [ ! -f "${obs_dir}/${file}" ]; then
      echo "ERROR: ${file} not found in OBS package"
      return 1
    fi
  done

  return 0
}

# Extract chart contents from OBS package tarball.
# Args: $1 (string) - Path to OBS package directory
#       $2 (string) - Destination chart directory path
# Returns: 0 on success, 1 on failure
extract_chart_contents() {
  local obs_dir="$1"
  local chart_dir="$2"

  echo "Extracting upstream chart contents from contents.tar.gz..."

  mkdir -p "${chart_dir}"

  if ! tar -xzf "${obs_dir}/contents.tar.gz" -C "${chart_dir}" 2>/dev/null; then
    echo "ERROR: Failed to extract contents.tar.gz"
    return 1
  fi

  echo "Contents of extracted tarball:"
  ls -laR "${chart_dir}/"

  return 0
}

# Copy Chart.yaml from OBS package to chart directory.
# Args: $1 (string) - Path to OBS package directory
#       $2 (string) - Destination chart directory
# Returns: 0 on success, 1 on failure
copy_chart_yaml() {
  local obs_dir="$1"
  local chart_dir="$2"

  echo "Copying Chart.yaml to upstream chart..."

  if ! cp "${obs_dir}/Chart.yaml" "${chart_dir}/"; then
    echo "ERROR: Failed to copy Chart.yaml"
    return 1
  fi

  if [ ! -f "${chart_dir}/Chart.yaml" ]; then
    echo "ERROR: Chart.yaml not found in chart directory after copy"
    return 1
  fi

  return 0
}

# Display chart directory structure.
# Args: $1 (string) - Path to chart directory
display_chart_structure() {
  local chart_dir="$1"

  echo "Final chart directory structure:"
  ls -la "${chart_dir}/"

  if [ -d "${chart_dir}/templates" ]; then
    local template_count
    template_count=$(ls -1 "${chart_dir}/templates" | wc -l)
    echo "Templates directory exists with ${template_count} files"
  fi
}

# Create RPM macros file for OBS buildtime services.
# Args: $1 (string, optional) - Registry URL (default: registry.suse.com)
#       $2 (string, optional) - Image repository prefix (default: trento)
#       $3 (string, optional) - Output file path (default: /root/.rpmmacros)
# Returns: 0 on success, 1 on failure
create_rpm_macros() {
  local registry_url="${1:-registry.suse.com}"
  local repo_prefix="${2:-trento}"
  local output_file="${3:-/root/.rpmmacros}"

  cat > "$output_file" <<EOF
%registry_url ${registry_url}
%img_repository_prefix ${repo_prefix}
EOF

  return 0
}

# Extract buildtime service section from _service file.
# Args: $1 (string) - Path to _service file
# Outputs: Buildtime service XML section
extract_buildtime_service() {
  local service_file="$1"

  sed -n '/<service.*mode="buildtime"/,/<\/service>/p' "${service_file}"
}

# Extract file parameter from replace_using_env service.
# Args: $1 (string) - Buildtime service XML content
# Outputs: File parameter value
# Returns: 0 on success, 1 if not found
extract_file_parameter() {
  local service_xml="$1"

  local file_param
  file_param=$(echo "$service_xml" | grep 'param name="file"' | sed 's/.*>\(.*\)<.*/\1/' | head -n1)

  if [ -z "$file_param" ]; then
    echo "ERROR: replace_using_env file parameter not found" >&2
    return 1
  fi

  echo "$file_param"
  return 0
}

# Build command array for replace_using_env service.
# Args: $1 (string) - File parameter value
#       $2 (string) - Buildtime service XML content
# Outputs: Executes replace_using_env command
# Returns: 0 on success, 1 on failure
run_replace_using_env() {
  local file_param="$1"
  local service_xml="$2"

  # Build the command as an argv array to avoid eval/injection
  local cmd=(/usr/lib/obs/service/replace_using_env --file "${file_param}")

  # Process eval and var parameters (multiple)
  while IFS= read -r param_line; do
    local param_name param_value
    param_name=$(echo "$param_line" | sed 's/.*name="\([^"]*\)".*/\1/')
    param_value=$(echo "$param_line" | sed 's/.*>\(.*\)<.*/\1/')
    cmd+=("--${param_name}" "${param_value}")
  done < <(echo "$service_xml" | grep 'param name=' | grep -E '(eval|var)')

  if ! "${cmd[@]}" > /dev/null 2>&1; then
    echo "ERROR: replace_using_env failed"
    return 1
  fi

  return 0
}

# Process OBS buildtime services from _service file.
# Args: $1 (string) - Path to OBS package directory
#       $2 (string) - Path to chart directory
# Returns: 0 on success, 1 on failure
process_buildtime_services() {
  local obs_dir="$1"
  local chart_dir="$2"

  echo "Running buildtime services from _service..."

  local buildtime_service
  buildtime_service=$(extract_buildtime_service "${obs_dir}/_service")

  # Check if replace_using_env service exists
  if echo "$buildtime_service" | grep -q 'name="replace_using_env"'; then
    local file_param
    if ! file_param=$(extract_file_parameter "$buildtime_service"); then
      return 1
    fi

    # Run from OBS directory to process files in place
    if ! (cd "${obs_dir}" && run_replace_using_env "${file_param}" "$buildtime_service"); then
      return 1
    fi

    # Copy the processed values.yaml to the extracted chart
    echo "Copying processed values.yaml to upstream chart..."
    if ! cp "${obs_dir}/values.yaml" "${chart_dir}/values.yaml"; then
      echo "ERROR: Failed to copy processed values.yaml"
      return 1
    fi
  fi

  return 0
}

# Copy OBS artifacts to workspace.
# Args: $1 (string) - Source chart directory
#       $2 (string) - Destination workspace directory
# Returns: 0 on success, 1 on failure
copy_obs_artifacts() {
  local chart_dir="$1"
  local workspace_dir="$2"

  echo "Copying upstream chart to workspace..."

  if ! cp -r "${chart_dir}" "${workspace_dir}/chart"; then
    echo "ERROR: Failed to copy chart to workspace"
    return 1
  fi

  if ! cp "${workspace_dir}/chart/values.yaml" "${workspace_dir}/values-obs.yaml"; then
    echo "ERROR: Failed to copy values-obs.yaml"
    return 1
  fi

  return 0
}

# Process OBS package artifacts.
# Args: $1 (string) - Git source URL
#       $2 (string) - Workspace directory (default: /workspace/obs-artifacts)
# Returns: 0 on success, 1 on failure
process_obs_package() {
  local git_source_url="$1"
  local workspace_dir="${2:-/workspace/obs-artifacts}"
  local work_dir
  work_dir=$(mktemp -d)

  local obs_dir chart_dir

  # Fetch and verify OBS package
  if ! obs_dir=$(fetch_obs_package "${git_source_url}" "${work_dir}"); then
    return 1
  fi

  if ! verify_obs_package_files "${obs_dir}"; then
    return 1
  fi

  # Extract and prepare chart
  chart_dir="${work_dir}/upstream-chart"
  if ! extract_chart_contents "${obs_dir}" "${chart_dir}"; then
    return 1
  fi

  if ! copy_chart_yaml "${obs_dir}" "${chart_dir}"; then
    return 1
  fi

  display_chart_structure "${chart_dir}"

  # Process buildtime services
  create_rpm_macros "registry.suse.com" "trento"

  if ! process_buildtime_services "${obs_dir}" "${chart_dir}"; then
    return 1
  fi

  # Copy to workspace
  if ! copy_obs_artifacts "${chart_dir}" "${workspace_dir}"; then
    return 1
  fi

  echo "OBS package processing completed successfully"
  return 0
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
    process-obs-package)
      shift
      process_obs_package "$@"
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
      printf '%s\n' "  process-obs-package <git-url> [workspace-dir]" >&2
      exit 1
      ;;
  esac
}

# Only run main when executed directly (not when sourced for tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
