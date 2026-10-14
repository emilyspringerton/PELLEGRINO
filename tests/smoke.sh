#!/usr/bin/env bash
# Runs pellegrino --smoke under Xvfb in a scratch dir and asserts on the text log it leaves behind.
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pellegrino"
[ -x "$BIN" ] || BIN="$TEST_SRCDIR/${TEST_WORKSPACE:-_main}/pellegrino"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" --smoke
for needle in "pellegrino v0 start" "source bytes=" "window+renderer up" "smoke limit reached" "clean exit"; do
  grep -q "$needle" pellegrino.log || { echo "FAIL: '$needle' missing from pellegrino.log"; cat pellegrino.log; exit 1; }
done
echo "smoke OK"; cat pellegrino.log
