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
  render_configmap "$@" | grep -m1 -E '^[[:space:]]+LOG_LEVEL:' | sed -E 's/^[[:space:]]+//'
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

@test "log level: every level supported by the applications is rendered" {
  for level in debug info warning error; do
    run render_log_level web --set global.logLevel="${level}"
    [ "$status" -eq 0 ]
    [ "$output" = "LOG_LEVEL: \"${level}\"" ]

    run render_log_level wanda --set global.logLevel="${level}"
    [ "$status" -eq 0 ]
    [ "$output" = "LOG_LEVEL: \"${level}\"" ]
  done
}

@test "log level: an invalid global.logLevel fails the rendering" {
  run render_configmap web --set global.logLevel=verbose
  [ "$status" -ne 0 ]
  [[ "$output" == *'Invalid log level "verbose"'* ]]
  [[ "$output" == *'Valid values are: debug, info, warning, error'* ]]
}

@test "log level: an empty global.logLevel fails the rendering" {
  run render_configmap web --set global.logLevel=
  [ "$status" -ne 0 ]
  [[ "$output" == *'Invalid log level ""'* ]]
}

@test "log level: log levels are case sensitive" {
  run render_configmap web --set global.logLevel=INFO
  [ "$status" -ne 0 ]
  [[ "$output" == *'Invalid log level "INFO"'* ]]
}

@test "log level: an invalid component logLevel points to the component flag" {
  run render_configmap web --set trento-web.logLevel=warn
  [ "$status" -ne 0 ]
  [[ "$output" == *'Invalid log level "warn"'* ]]
  [[ "$output" == *'--set trento-web.logLevel=<level>'* ]]

  run render_configmap wanda --set trento-wanda.logLevel=notice
  [ "$status" -ne 0 ]
  [[ "$output" == *'Invalid log level "notice"'* ]]
  [[ "$output" == *'--set trento-wanda.logLevel=<level>'* ]]
}
