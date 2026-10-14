#!/usr/bin/env bash
# Builds with Bazel and writes dist/pellegrino_linux_x86_64.zip (binary + bundled libSDL2 + cacert.pem + RUN.sh
# + CONSTRUCT). cacert.pem is the fallback trust store for https:// (the program prefers SSL_CERT_FILE and the
# system bundle; see PARENA's net/stream).
set -euo pipefail
cd "$(dirname "$0")/.."
CA="${PELLEGRINO_CA_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}"
[ -s "$CA" ] && grep -q "BEGIN CERTIFICATE" "$CA" || { echo "no CA bundle at $CA (set PELLEGRINO_CA_BUNDLE)"; exit 1; }
BZ="${BAZEL:-bazelisk}"
$BZ build //:pellegrino ${BAZEL_FLAGS:-}
rm -rf dist/linux && mkdir -p dist/linux/lib
cp "$($BZ cquery //:pellegrino --output=files ${BAZEL_FLAGS:-} 2>/dev/null | head -1)" dist/linux/pellegrino
SDL="$(ldd dist/linux/pellegrino | awk '/libSDL2-2.0.so/ {print $3}')"
cp -L "$SDL" dist/linux/lib/
cp "$CA" dist/linux/cacert.pem
cp packaging/RUN.sh dist/linux/RUN.sh
[ -f PELLEGRINO_CONSTRUCT.txt ] && cp PELLEGRINO_CONSTRUCT.txt dist/linux/
(cd dist/linux && zip -qr ../pellegrino_linux_x86_64.zip .)
ls -la dist/pellegrino_linux_x86_64.zip
