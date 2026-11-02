#!/usr/bin/env bash
set -eu
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_LOG="$(mktemp "${TMPDIR:-/tmp}/punch-pop-tests.XXXXXX")"
TEST_PROJECT=""
cleanup() {
  rm -f "$TEST_LOG"
  if [[ -n "$TEST_PROJECT" ]]; then
    rm -rf "$TEST_PROJECT"
  fi
}
trap cleanup EXIT
# Sandboxed macOS cannot always read Keychain's public CA roots. Use the
# system's PEM bundle only in a disposable test project. Keep TLS verification
# and the strict engine-error check enabled; never ship a machine-local path.
TEST_LAUNCHER="$PROJECT_DIR/tools/run.sh"
if [[ "$(uname -s)" == Darwin && -r /etc/ssl/cert.pem ]]; then
  TEST_PROJECT="$(mktemp -d "${TMPDIR:-/tmp}/punch-pop-test-project.XXXXXX")"
  cp "$PROJECT_DIR/project.godot" "$TEST_PROJECT/project.godot"
  for resource in scripts scenes assets tests tools docs; do
    ln -s "$PROJECT_DIR/$resource" "$TEST_PROJECT/$resource"
  done
  if [[ -d "$PROJECT_DIR/.godot" ]]; then
    cp -R "$PROJECT_DIR/.godot" "$TEST_PROJECT/.godot"
  fi
  cat > "$TEST_PROJECT/override.cfg" <<'EOF'
[network]
tls/certificate_bundle_override="/etc/ssl/cert.pem"
EOF
  TEST_LAUNCHER="$TEST_PROJECT/tools/run.sh"
fi
TEST_SCRIPT=res://tests/test_runner.gd
TEST_SUCCESS='Punch Pop: [0-9]+ checks, 0 failures'
if [[ "${1:-}" == "--real-clock" ]]; then
  TEST_SCRIPT=res://tools/pressure_runtime_smoke.gd
  TEST_SUCCESS='Punch Pop real clock: [0-9]+ checks, 0 failures'
elif [[ "${1:-}" == "--flow" ]]; then
  TEST_SCRIPT=res://tests/v7_flow.gd
  TEST_SUCCESS='Punch Pop flow: [0-9]+ checks, 0 failures'
elif [[ "${1:-}" == "--stress" ]]; then
  TEST_SCRIPT=res://tests/stress_flow.gd
  TEST_SUCCESS='Punch Pop stress: [0-9]+ checks, 0 failures'
elif [[ "${1:-}" == "--audit" ]]; then
  TEST_SCRIPT=res://tools/pressure_audit.gd
  TEST_SUCCESS='Saved docs/[^/]+\.json'
elif [[ "${1:-}" == "--lab" ]]; then
  TEST_SCRIPT=res://tools/curve_lab.gd
  TEST_SUCCESS='Lab complete'
elif [[ -n "${1:-}" ]]; then
  echo 'Usage: tools/test.sh [--real-clock|--flow|--stress|--audit|--lab]' >&2
  exit 2
fi
if [[ $# -gt 0 ]]; then
  shift
fi
"$TEST_LAUNCHER" --headless --script "$TEST_SCRIPT" --log-file "$TEST_LOG" -- "$@"
# Godot can exit 0 after a GDScript runtime error; do not accept that as a pass.
if grep -Eq '^(SCRIPT ERROR|ERROR):' "$TEST_LOG"; then
  echo 'Godot reported an error; the test run is not clean.' >&2
  exit 1
fi
if ! grep -Eq "$TEST_SUCCESS" "$TEST_LOG"; then
  echo 'The test suite did not report successful completion.' >&2
  exit 1
fi
