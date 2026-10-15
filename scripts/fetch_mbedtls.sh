#!/usr/bin/env bash
# Prints the path of the pinned mbedTLS source tree (third_party/mbedtls/mbedtls.env), downloading and
# sha256-verifying it on first use. Used by scripts/package_windows.sh; Bazel fetches the same pin itself.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
. third_party/mbedtls/mbedtls.env
DEST="${MBEDTLS_CACHE:-build/mbedtls}"
SRC="$DEST/mbedtls-$MBEDTLS_VERSION"
if [ ! -f "$SRC/library/ssl_tls.c" ]; then
  mkdir -p "$DEST"
  curl -fsSL -o "$DEST/mbedtls.tar.bz2" "$MBEDTLS_URL"
  echo "$MBEDTLS_SHA256  $DEST/mbedtls.tar.bz2" | sha256sum -c - >&2
  tar -xjf "$DEST/mbedtls.tar.bz2" -C "$DEST"
fi
case "$DEST" in /*) echo "$SRC" ;; *) echo "$PWD/$SRC" ;; esac
