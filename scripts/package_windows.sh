#!/usr/bin/env bash
# Cross-compiles pellegrino.exe (mingw-w64) from the Bazel-generated C and writes
# dist/pellegrino_windows.zip: a FLAT zip of pellegrino.exe + SDL2.dll + RUN.bat (+ CONSTRUCT).
#   SDL2_MINGW = SDL2 mingw x86_64 dir (has include/SDL2, lib/, bin/SDL2.dll)
#   PARENA_DIR = PARENA checkout whose runtime/ to link (default: Bazel's pinned external parena)
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SDL2_MINGW:?set SDL2_MINGW}"
BZ="${BAZEL:-bazelisk}"
$BZ build //:pellegrino_gen ${BAZEL_FLAGS:-}
GEN="$($BZ cquery //:pellegrino_gen --output=files ${BAZEL_FLAGS:-} 2>/dev/null | head -1)"
if [ -z "${PARENA_DIR:-}" ]; then PARENA_DIR="$($BZ info output_base ${BAZEL_FLAGS:-})/external/parena+"; fi
rm -rf dist/win build/win && mkdir -p dist/win build/win
cp "$GEN" build/win/pellegrino_gen.inc
x86_64-w64-mingw32-gcc -std=gnu99 -O2 -Wall -Wextra \
  -DPARENA_NO_MALLOC -DPARENA_NO_TTF -DPARENA_STATIC_POOL_BYTES=33554432 -DPARENA_STATIC_BLOCK_BYTES=262144 \
  ${PELLEGRINO_VERSION:+-DPELLEGRINO_VERSION=\"$PELLEGRINO_VERSION\"} \
  -I "$PARENA_DIR/runtime" -I build/win -I "$SDL2_MINGW/include" -I "$SDL2_MINGW/include/SDL2" \
  pellegrino_host.c "$PARENA_DIR/runtime/parena_runtime.c" \
  -o dist/win/pellegrino.exe -L "$SDL2_MINGW/lib" -lmingw32 -lSDL2main -lSDL2 -lm -lws2_32 -mwindows -static-libgcc
cp "$SDL2_MINGW/bin/SDL2.dll" dist/win/
cp packaging/RUN.bat dist/win/RUN.bat
[ -f PELLEGRINO_CONSTRUCT.txt ] && cp PELLEGRINO_CONSTRUCT.txt dist/win/
(cd dist/win && zip -qr ../pellegrino_windows.zip .)
file dist/win/pellegrino.exe; unzip -l dist/pellegrino_windows.zip
