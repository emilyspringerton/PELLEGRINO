#!/usr/bin/env bash
# Builds with Bazel and writes dist/pellegrino_linux_x86_64.zip (binary + bundled libSDL2 + cacert.pem + RUN.sh
# + CONSTRUCT). cacert.pem is the fallback trust store for https:// (the program prefers SSL_CERT_FILE and the
# system bundle; see PARENA's net/stream).
set -euo pipefail
cd "$(dirname "$0")/.."
# the sha256-pinned Mozilla bundle (third_party/cacert), not the build host's own store; override with
# PELLEGRINO_CA_BUNDLE for offline builds
CA="$(bash scripts/fetch_cacert.sh)" || { echo "no usable CA bundle; refusing to ship https:// without trust roots"; exit 1; }
BZ="${BAZEL:-bazelisk}"
$BZ build //:pellegrino ${BAZEL_FLAGS:-}
rm -rf dist/linux dist/pellegrino_linux_x86_64.zip && mkdir -p dist/linux/lib
cp "$($BZ cquery //:pellegrino --output=files ${BAZEL_FLAGS:-} 2>/dev/null | head -1)" dist/linux/pellegrino
SDL="$(ldd dist/linux/pellegrino | awk '/libSDL2-2.0.so/ {print $3}')"
cp -L "$SDL" dist/linux/lib/
cp "$CA" dist/linux/cacert.pem
cp packaging/RUN.sh dist/linux/RUN.sh
[ -f PELLEGRINO_CONSTRUCT.txt ] && cp PELLEGRINO_CONSTRUCT.txt dist/linux/ || true
(cd dist/linux && zip -qr ../pellegrino_linux_x86_64.zip .)
ls -la dist/pellegrino_linux_x86_64.zip
