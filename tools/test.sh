#!/usr/bin/env bash
set -eu
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_LOG="$(mktemp "${TMPDIR:-/tmp}/punch-pop-tests.XXXXXX")"
trap 'rm -f "$TEST_LOG"' EXIT
TEST_SCRIPT=res://tests/test_runner.gd
TEST_SUCCESS='Punch Pop: [0-9]+ checks, 0 failures'
if [[ "${1:-}" == "--real-clock" ]]; then
  TEST_SCRIPT=res://tools/pressure_runtime_smoke.gd
  TEST_SUCCESS='Punch Pop real clock: [0-9]+ checks, 0 failures'
fi
"$PROJECT_DIR/tools/run.sh" --headless --script "$TEST_SCRIPT" --log-file "$TEST_LOG"
# Godot can exit 0 after a GDScript runtime error; do not accept that as a pass.
if grep -Eq '^(SCRIPT ERROR|ERROR):' "$TEST_LOG"; then
  echo 'Godot reported an error; the test run is not clean.' >&2
  exit 1
fi
if ! grep -Eq "$TEST_SUCCESS" "$TEST_LOG"; then
  echo 'The test suite did not report successful completion.' >&2
  exit 1
fi
