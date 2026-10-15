#!/usr/bin/env bash
# Build + run tests/embed_test.c against a sibling ../PARENA checkout (needs SDL2 headers; SDL_VIDEODRIVER=dummy
# so no display is required). Usage: scripts/embed_test.sh [out.ppm]
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
P="${PARENA:-$here/../PARENA}"
S="$P/stdlib"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
"$P/parena" build "$S/string.prn" "$S/array.prn" "$S/io.prn" "$S/sdl2.prn" "$S/bytes.prn" "$S/compress/inflate.prn" \
  "$S/image/png.prn" "$S/image/store.prn" "$S/net/stream.prn" "$here/pellegrino.prn" -o "$tmp/pellegrino_gen.inc"
cc -O1 -DPARENA_NO_MALLOC -DPARENA_NO_TTF -I"$tmp" -I"$P/runtime" -o "$tmp/embed_test" "$here/tests/embed_test.c" \
  "$P/runtime/parena_runtime.c" -lSDL2 -lm
SDL_VIDEODRIVER=dummy "$tmp/embed_test" "${1:-$here/embed_frame.ppm}"
