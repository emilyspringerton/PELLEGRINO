#!/usr/bin/env bash
# Deterministic source snapshot (monorepo Principle 21): same git tree => byte-identical output.
set -euo pipefail
export LC_ALL=C
OUT="${1:-PELLEGRINO_CONSTRUCT.txt}"
TREE_SHA="$(git rev-parse --verify 'HEAD^{tree}' 2>/dev/null || printf 'unknown')"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
git ls-files -z \
  ':(exclude)*_CONSTRUCT*.txt' ':(exclude)MANIFEST*.txt' ':(exclude)vendor/**' \
  ':(exclude)node_modules/**' ':(exclude)build/**' ':(exclude)dist/**' | sort -z > "$TMP"
{ printf 'PELLEGRINO CONSTRUCT\nschema_version: 1\ntree_sha: %s\nsource: git ls-files\n\n' "$TREE_SHA"; } > "$OUT"
COUNT=0
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  SHA="$(sha256sum "$f" | awk '{print $1}')"; SIZE="$(wc -c < "$f")"
  MODE="$(git ls-files -s -- "$f" | awk '{print $1}')"
  if grep -qI . "$f" || [ ! -s "$f" ]; then ENC=text; else ENC=base64; fi
  { printf -- '--- FILE START: %s ---\nsha256: %s\nsize_bytes: %s\ngit_mode: %s\nencoding: %s\n--- CONTENT START ---\n' "$f" "$SHA" "$SIZE" "$MODE" "$ENC"
    if [ "$ENC" = text ]; then cat "$f"; else base64 "$f"; fi
    printf '\n--- CONTENT END ---\n--- FILE END: %s ---\n\n' "$f"; } >> "$OUT"
  COUNT=$((COUNT+1))
done < "$TMP"
printf 'Generated %s with %d files (tree_sha: %s)\n' "$OUT" "$COUNT" "$TREE_SHA"
