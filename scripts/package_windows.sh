#!/usr/bin/env bash
# Cross-compiles pellegrino.exe (mingw-w64) from the Bazel-generated C and writes
# dist/pellegrino_windows.zip: a FLAT zip of pellegrino.exe + SDL2.dll + cacert.pem + RUN.bat (+ CONSTRUCT).
#   SDL2_MINGW            = SDL2 mingw x86_64 dir (has include/SDL2, lib/, bin/SDL2.dll)
#   PARENA_DIR            = PARENA checkout whose runtime/ to link (default: Bazel's pinned external parena)
#   PELLEGRINO_CA_BUNDLE  = PEM bundle shipped as cacert.pem. Default: the sha256-pinned Mozilla bundle
#                           (third_party/cacert, scripts/fetch_cacert.sh) -- never the build host's own store.
#                           Windows has no system file; this is the whole trust store https:// uses there.
# https:// support: the pinned mbedTLS (third_party/mbedtls/mbedtls.env) is compiled here with the same
# user config as the Bazel build, and PARENA's runtime links it with a static heap (no malloc).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SDL2_MINGW:?set SDL2_MINGW}"
CA="$(bash scripts/fetch_cacert.sh)" || { echo "no usable CA bundle; refusing to ship https:// without trust roots"; exit 1; }
BZ="${BAZEL:-bazelisk}"
$BZ build //:pellegrino_gen ${BAZEL_FLAGS:-}
GEN="$($BZ cquery //:pellegrino_gen --output=files ${BAZEL_FLAGS:-} 2>/dev/null | head -1)"
if [ -z "${PARENA_DIR:-}" ]; then PARENA_DIR="$($BZ info output_base ${BAZEL_FLAGS:-})/external/parena+"; fi
MB="$(bash scripts/fetch_mbedtls.sh)"
CC="${MINGW_CC:-x86_64-w64-mingw32-gcc}"
rm -rf dist/win build/win dist/pellegrino_windows.zip && mkdir -p dist/win build/win/mbedtls
cp "$GEN" build/win/pellegrino_gen.inc

# mbedTLS, compiled with mingw under PELLEGRINO's user config (static-heap allocator on).
mbedtls_obj() { # $1 = source file
  "$CC" -std=gnu99 -O2 -w -c -I"$MB/include" -I"$MB/library" -Ithird_party/mbedtls \
    "-DMBEDTLS_USER_CONFIG_FILE=\"pellegrino_user_config.h\"" "$1" -o "build/win/mbedtls/$(basename "$1" .c).o"
}
export -f mbedtls_obj
export CC MB
printf '%s\0' "$MB"/library/*.c | xargs -0 -n 1 -P "$(nproc)" bash -c 'mbedtls_obj "$1"' _

"$CC" -std=gnu99 -O2 -Wall -Wextra \
  -DPARENA_NO_MALLOC -DPARENA_NO_TTF -DPARENA_STATIC_POOL_BYTES=33554432 -DPARENA_STATIC_BLOCK_BYTES=262144 \
  -DPARENA_WITH_TLS -DPARENA_TLS_STATIC_HEAP -DPARENA_TLS_HEAP_STATS \
  "-DMBEDTLS_USER_CONFIG_FILE=\"pellegrino_user_config.h\"" \
  ${PELLEGRINO_VERSION:+-DPELLEGRINO_VERSION=\"$PELLEGRINO_VERSION\"} \
  -I "$PARENA_DIR/runtime" -I build/win -I "$SDL2_MINGW/include" -I "$SDL2_MINGW/include/SDL2" \
  -I "$MB/include" -I third_party/mbedtls \
  pellegrino_host.c "$PARENA_DIR/runtime/parena_runtime.c" build/win/mbedtls/*.o \
  -o dist/win/pellegrino.exe -L "$SDL2_MINGW/lib" -lmingw32 -lSDL2main -lSDL2 -lm -lws2_32 -lbcrypt -mwindows -static-libgcc
cp "$SDL2_MINGW/bin/SDL2.dll" dist/win/
cp "$CA" dist/win/cacert.pem
cp packaging/RUN.bat dist/win/RUN.bat
[ -f PELLEGRINO_CONSTRUCT.txt ] && cp PELLEGRINO_CONSTRUCT.txt dist/win/ || true
(cd dist/win && zip -qr ../pellegrino_windows.zip .)
file dist/win/pellegrino.exe; unzip -l dist/pellegrino_windows.zip
