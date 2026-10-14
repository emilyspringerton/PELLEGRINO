#!/usr/bin/env bash
# PELLEGRINO launcher (Linux). Uses the bundled libSDL2 next to this script; logs go to real files in
# this directory (pellegrino.log, pellegrino.out.log, pellegrino.err.log).
cd "$(dirname "$0")"
export LD_LIBRARY_PATH="$PWD/lib:${LD_LIBRARY_PATH:-}"
./pellegrino "$@"
rc=$?
echo "PELLEGRINO exited with code $rc (logs: $PWD/pellegrino.log, pellegrino.err.log)"
exit $rc
