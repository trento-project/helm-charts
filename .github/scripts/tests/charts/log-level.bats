#!/usr/bin/env bats

# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: Apache-2.0

# Test suite for the LOG_LEVEL entry rendered in the trento-web and
# trento-wanda ConfigMaps, driven by global.logLevel and the per component
# logLevel override.
#
# Unlike the suites in the parent directory, these tests run the real helm
# binary against the trento-server chart, so its dependencies must be built
# beforehand.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  CHART_DIR="${REPO_ROOT}/charts/trento-server"
}

# Renders the ConfigMap of the given component, forwarding any extra argument
# to helm.
render_configmap() {
  local component="$1"
  shift

  helm template test "${CHART_DIR}" \
    --set prometheus.server.auth.type=none \
    "$@" \
    --show-only "charts/trento-${component}/templates/configmap.yaml"
}

# Prints the raw LOG_LEVEL line of the given component ConfigMap, so that both
# the value and its quoting are asserted.
render_log_level() {
  render_configmap "$@" | sed -nE '/^[[:space:]]+LOG_LEVEL:/{s/^[[:space:]]+//;p;q;}'
}

@test "log level: defaults to info on both components" {
  run render_log_level web
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "info"' ]

  run render_log_level wanda
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "info"' ]
}

@test "log level: global.logLevel is propagated to both components" {
  run render_log_level web --set global.logLevel=debug
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "debug"' ]

  run render_log_level wanda --set global.logLevel=debug
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "debug"' ]
}

@test "log level: component logLevel only overrides its own component" {
  run render_log_level web --set trento-web.logLevel=warning
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "warning"' ]

  run render_log_level wanda --set trento-web.logLevel=warning
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "info"' ]
}

@test "log level: component logLevel takes precedence over global.logLevel" {
  run render_log_level web --set global.logLevel=debug --set trento-web.logLevel=error
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "error"' ]

  run render_log_level wanda --set global.logLevel=debug --set trento-wanda.logLevel=error
  [ "$status" -eq 0 ]
  [ "$output" = 'LOG_LEVEL: "error"' ]
}
