#!/usr/bin/env bash
# Prints the path of the pinned Mozilla CA bundle (third_party/cacert/cacert.env), downloading and
# sha256-verifying it on first use, then proving it is a real bundle by parsing it. Used by
# scripts/package_{linux,windows}.sh. PELLEGRINO_CA_BUNDLE=/path overrides the source (offline builds,
# a private PKI) but is still parsed and counted.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
. third_party/cacert/cacert.env
MIN_CERTS="${PELLEGRINO_CA_MIN_CERTS:-100}"
if [ -n "${PELLEGRINO_CA_BUNDLE:-}" ]; then
  CA="$PELLEGRINO_CA_BUNDLE"
  [ -s "$CA" ] || { echo "PELLEGRINO_CA_BUNDLE=$CA is empty or missing" >&2; exit 1; }
else
  DEST="${CACERT_CACHE:-build/cacert}"
  CA="$DEST/cacert-$CACERT_DATE.pem"
  if [ ! -s "$CA" ]; then
    mkdir -p "$DEST"
    curl -fsSL -o "$CA.tmp" "$CACERT_URL"
    echo "$CACERT_SHA256  $CA.tmp" | sha256sum -c - >&2
    mv "$CA.tmp" "$CA"
  fi
fi
# a substring grep is not validation: count certificates that actually parse
N="$(openssl crl2pkcs7 -nocrl -certfile "$CA" 2>/dev/null | openssl pkcs7 -print_certs -noout 2>/dev/null | grep -c '^subject=' || true)"
if [ "${N:-0}" -lt "$MIN_CERTS" ]; then
  echo "$CA: only ${N:-0} parseable certificates (need >= $MIN_CERTS); refusing to ship it as the trust store" >&2
  exit 1
fi
echo "ca bundle: $CA ($N certificates, sha256 $(sha256sum "$CA" | awk '{print $1}'))" >&2
case "$CA" in /*) echo "$CA" ;; *) echo "$PWD/$CA" ;; esac
