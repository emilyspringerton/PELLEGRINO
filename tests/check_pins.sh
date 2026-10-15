#!/usr/bin/env bash
# The mbedTLS pin lives in two places that cannot read each other (MODULE.bazel for Bazel,
# third_party/mbedtls/mbedtls.env for scripts/fetch_mbedtls.sh). Fail loudly if they ever diverge.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
[ -f "$ROOT/MODULE.bazel" ] || ROOT="${TEST_SRCDIR:-}/${TEST_WORKSPACE:-_main}"
# shellcheck disable=SC1091
. "$ROOT/third_party/mbedtls/mbedtls.env"
grep -q "sha256 = \"$MBEDTLS_SHA256\"" "$ROOT/MODULE.bazel" || { echo "FAIL: MODULE.bazel sha256 != mbedtls.env"; exit 1; }
grep -q "urls = \[\"$MBEDTLS_URL\"\]" "$ROOT/MODULE.bazel" || { echo "FAIL: MODULE.bazel url != mbedtls.env"; exit 1; }
grep -q "strip_prefix = \"mbedtls-$MBEDTLS_VERSION\"" "$ROOT/MODULE.bazel" || { echo "FAIL: MODULE.bazel strip_prefix != mbedtls.env"; exit 1; }
echo "pins OK (mbedTLS $MBEDTLS_VERSION)"
