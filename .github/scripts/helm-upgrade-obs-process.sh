#!/usr/bin/env bash

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# Fetch OBS package from git mirror
echo "Fetching OBS package from ${GIT_SOURCE_URL}..."

WORK_DIR=$(mktemp -d)
cd "${WORK_DIR}"

git clone --depth 1 "${GIT_SOURCE_URL}" obs-package
cd obs-package

if [ ! -f values.yaml ]; then
  echo "ERROR: values.yaml not found"
  exit 1
fi

if [ ! -f _service ]; then
  echo "ERROR: _service not found"
  exit 1
fi

if [ ! -f contents.tar.gz ]; then
  echo "ERROR: contents.tar.gz not found"
  exit 1
fi

# Extract the upstream chart
echo "Extracting upstream chart from contents.tar.gz..."
CHART_DIR="${WORK_DIR}/upstream-chart"
mkdir -p "${CHART_DIR}"
tar -xzf contents.tar.gz -C "${CHART_DIR}"

# Verify chart structure
if [ ! -f "${CHART_DIR}/Chart.yaml" ]; then
  echo "ERROR: Chart.yaml not found in extracted contents"
  exit 1
fi

# Create RPM macros (needed by buildtime services)
cat > /root/.rpmmacros <<"RPMEOF"
%registry_url registry.suse.com
%img_repository_prefix trento
RPMEOF

# Run buildtime services by parsing _service file
echo "Running buildtime services from _service..."

# Extract buildtime service section
BUILDTIME_SERVICE=$(sed -n '/<service.*mode="buildtime"/,/<\/service>/p' _service)

# Check if replace_using_env service exists
if echo "$BUILDTIME_SERVICE" | grep -q 'name="replace_using_env"'; then
  # Extract file parameter
  FILE_PARAM=$(echo "$BUILDTIME_SERVICE" | grep 'param name="file"' | sed 's/.*>\(.*\)<.*/\1/' | head -n1)
  if [ -z "$FILE_PARAM" ]; then
    echo "ERROR: replace_using_env file parameter not found"
    exit 1
  fi

  # Process the values.yaml file in the OBS package directory
  # Build the command as an argv array to avoid eval/injection
  cmd=(/usr/lib/obs/service/replace_using_env --file "${FILE_PARAM}")

  # Process eval and var parameters (multiple)
  while IFS= read -r param_line; do
    PARAM_NAME=$(echo "$param_line" | sed 's/.*name="\([^"]*\)".*/\1/')
    PARAM_VALUE=$(echo "$param_line" | sed 's/.*>\(.*\)<.*/\1/')
    cmd+=("--${PARAM_NAME}" "${PARAM_VALUE}")
  done < <(echo "$BUILDTIME_SERVICE" | grep 'param name=' | grep -E '(eval|var)')

  "${cmd[@]}" > /dev/null

  # Copy the processed values.yaml to the extracted chart
  echo "Copying processed values.yaml to upstream chart..."
  cp values.yaml "${CHART_DIR}/values.yaml"
fi

# Copy the upstream chart and processed values to workspace
echo "Copying upstream chart to workspace..."
cp -r "${CHART_DIR}" /workspace/obs-artifacts/chart
cp /workspace/obs-artifacts/chart/values.yaml /workspace/obs-artifacts/values-obs.yaml
