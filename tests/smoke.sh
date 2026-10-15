#!/usr/bin/env bash
# Runs pellegrino under Xvfb in a scratch dir and asserts on the text log it leaves behind:
#   1. --smoke                         embedded page
#   2. live HTTP                       streams, headers, body from a local server
#   3. 301 redirect                    followed
#   4. HTTPS, trusted certificate      TLS handshake + verified chain/hostname + body
#   5. HTTPS, large multi-record body  more than one TLS record
#   6. HTTPS, untrusted certificate    refused, nothing rendered
#   7. HTTPS, wrong hostname           refused (chain is trusted, name is not)
#   8. SSL_CERT_FILE unreadable        fails closed (no silent fallback)
#   9. HTTP -> HTTPS redirect          followed into TLS
#  10. navigate away mid-stream        the live stream being left is closed (no fd / TLS session leak)
#  11. TLS clean close                 an authenticated close_notify is not flagged
#  12. TLS truncation                  a stream cut without close_notify is flagged, never shown as complete
#  13. refused connect fails fast      a closed port must not cost the 5 s connect timeout (Winsock reports a
#                                      failed non-blocking connect via exceptfds, not writefds)
#  14. bundle beside the exe           (Windows/Wine only: PELLEGRINO_WINE + PELLEGRINO_EXE_DIR) cacert.pem next
#                                      to the exe is found even when its directory is not ANSI-representable
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PELLEGRINO_BIN overrides the binary for ad-hoc runs; under `bazel test` it comes from the runfiles.
BIN="${PELLEGRINO_BIN:-$(cd "$HERE/.." && pwd)/pellegrino}"
[ -x "$BIN" ] || BIN="${TEST_SRCDIR:-}/${TEST_WORKSPACE:-_main}/pellegrino"
SERVER="$HERE/smoke_server.py"
[ -f "$SERVER" ] || SERVER="${TEST_SRCDIR:-}/${TEST_WORKSPACE:-_main}/tests/smoke_server.py"
WORK="$(mktemp -d)"
PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done; rm -rf "$WORK"; }
trap cleanup EXIT
cd "$WORK"

need() { grep -q -- "$1" pellegrino.log || { echo "FAIL: '$1' missing from pellegrino.log"; cat pellegrino.log; exit 1; }; }
absent() { if grep -q -- "$1" pellegrino.log; then echo "FAIL: '$1' must not appear in pellegrino.log"; cat pellegrino.log; exit 1; fi; }
run() { rm -f pellegrino.log pellegrino.out.log pellegrino.err.log; xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" "$@"; }
free_port() { echo $((20000 + RANDOM % 20000)); }
wait_port() { for _ in $(seq 1 80); do (echo > "/dev/tcp/127.0.0.1/$1") 2>/dev/null && return 0; sleep 0.1; done; echo "server on $1 did not start"; exit 1; }
serve() { python3 "$SERVER" "$@" & PIDS+=($!); }
mkcert() { # name cn  -> name.pem name.key ; SAN = DNS:cn
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 2 \
    -keyout "$1.key" -out "$1.pem" -subj "/CN=$2" -addext "subjectAltName=DNS:$2" >/dev/null 2>&1
}

echo "== 1. embedded page"
run --smoke
for n in "pellegrino v1 start" "source bytes=" "window+renderer up" "smoke limit reached" "clean exit"; do need "$n"; done
absent "stream closed"   # no connection was ever opened: nothing may be pulled from or closed (fd 0 is not ours)

mkdir www
printf '<html><body><h1>hello from the wire</h1><p>streamed over plain http</p></body></html>\n' > www/index.html
python3 - > www/big.html <<'PY'
print("<html><body>")
for i in range(3000):
    print("<p>line %05d: the quick brown fox jumps over the lazy dog</p>" % i)
print("</body></html>")
PY
BIGBYTES=$(wc -c < www/big.html)

PORT=$(free_port)
serve "$PORT" www --redirect-to "https://localhost:0/index.html"
wait_port "$PORT"
echo "== 2. live HTTP"
run "--smoke-url=http://127.0.0.1:$PORT/index.html"
for n in "navigate http://127.0.0.1:$PORT/index.html" "connected; fd=" "http status=200" "stream closed; bytes=" "clean exit"; do need "$n"; done
absent "tls "

echo "== 3. redirect"
run "--smoke-url=http://127.0.0.1:$PORT/old"
for n in "http status=301" "navigate http://127.0.0.1:$PORT/index.html" "http status=200" "clean exit"; do need "$n"; done

mkcert good localhost
mkcert other unrelated.example
mkcert wrong other.example
TLSPORT=$(free_port)
serve "$TLSPORT" www good.pem good.key
wait_port "$TLSPORT"

echo "== 4. https, trusted certificate"
SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=https://localhost:$TLSPORT/index.html"
for n in "navigate https://localhost:$TLSPORT/index.html" "tls TLSv1" "connected; fd=" "http status=200" "stream closed; bytes=" "clean exit"; do need "$n"; done
absent "tls FAILED"

echo "== 5. https, large body (several TLS records)"
SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=https://localhost:$TLSPORT/big.html"
need "http status=200"
GOT=$(grep -o "stream closed; bytes=[0-9]*" pellegrino.log | grep -o "[0-9]*$")
[ "$GOT" -ge "$BIGBYTES" ] || { echo "FAIL: got $GOT bytes, body alone is $BIGBYTES"; cat pellegrino.log; exit 1; }
need "tls heap peak="

echo "== 6. https, untrusted certificate is refused"
SSL_CERT_FILE="$WORK/other.pem" run "--smoke-url=https://localhost:$TLSPORT/index.html"
for n in "tls FAILED: certificate rejected" "clean exit"; do need "$n"; done
absent "http status="
absent "connected; fd="

echo "== 7. https, wrong hostname is refused"
WRONGPORT=$(free_port)
serve "$WRONGPORT" www wrong.pem wrong.key
wait_port "$WRONGPORT"
SSL_CERT_FILE="$WORK/wrong.pem" run "--smoke-url=https://localhost:$WRONGPORT/index.html"
for n in "tls FAILED: certificate rejected" "does not match" "clean exit"; do need "$n"; done
absent "http status="

echo "== 8. unreadable SSL_CERT_FILE fails closed"
SSL_CERT_FILE="$WORK/does-not-exist.pem" run "--smoke-url=https://localhost:$TLSPORT/index.html"
for n in "tls FAILED: SSL_CERT_FILE" "clean exit"; do need "$n"; done
absent "http status="

echo "== 9. http -> https redirect"
HPORT=$(free_port)
serve "$HPORT" www --redirect-to "https://localhost:$TLSPORT/index.html"
wait_port "$HPORT"
SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=http://127.0.0.1:$HPORT/hop"
for n in "http status=301" "navigate https://localhost:$TLSPORT/index.html" "tls TLSv1" "http status=200" "clean exit"; do need "$n"; done

echo "== 10. navigating away from a live stream closes it"
run "--smoke-nav=http://127.0.0.1:$PORT/hang http://127.0.0.1:$PORT/index.html"
for n in "smoke-nav: address-bar navigation" "navigation closes live stream" "http status=200" "clean exit"; do need "$n"; done
# the second connection reuses the first one's descriptor number only if the first was really closed
NFD=$(grep -o "connected; fd=[0-9]*" pellegrino.log | sort -u | wc -l)
[ "$NFD" -eq 1 ] || { echo "FAIL: navigation leaked the previous socket ($NFD distinct fds)"; cat pellegrino.log; exit 1; }
SSL_CERT_FILE="$WORK/good.pem" run "--smoke-nav=https://localhost:$TLSPORT/hang https://localhost:$TLSPORT/index.html"
for n in "navigation closes live stream" "stream closed; bytes=" "clean exit"; do need "$n"; done
absent "tls FAILED"
[ "$(grep -c 'http status=200' pellegrino.log)" -eq 2 ] || { echo "FAIL: expected both pages to load"; cat pellegrino.log; exit 1; }

echo "== 11. TLS stream that ends with close_notify is not flagged"
CPORT=$(free_port)
openssl s_server -accept "$CPORT" -cert good.pem -key good.key -www -quiet >/dev/null 2>&1 &
PIDS+=($!)
wait_port "$CPORT"
SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=https://localhost:$CPORT/"
for n in "http status=200" "stream closed; bytes=" "clean exit"; do need "$n"; done
absent "WITHOUT close_notify"

echo "== 12. TLS stream cut without close_notify is flagged"
SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=https://localhost:$TLSPORT/trunc"
for n in "http status=200" "tls: stream ended WITHOUT close_notify" "stream closed; bytes=" "clean exit"; do need "$n"; done
run "--smoke-url=http://127.0.0.1:$PORT/trunc"
absent "WITHOUT close_notify"

echo "== 13. a refused connection fails fast (no 5 s connect timeout)"
ms() { echo $(( $(date +%s%N) / 1000000 )); }
B0=$(ms); run --smoke; B1=$(ms)
CLOSED=$(free_port)
run "--smoke-url=http://127.0.0.1:$CLOSED/"; B2=$(ms)
need "connect FAILED"
EXTRA=$(( (B2 - B1) - (B1 - B0) ))
[ "$EXTRA" -lt 3000 ] || { echo "FAIL: refused connect took ${EXTRA} ms longer than an idle run (connect timeout?)"; cat pellegrino.log; exit 1; }

if [ -n "${PELLEGRINO_WINE:-}" ] && [ -d "${PELLEGRINO_EXE_DIR:-/nonexistent}" ]; then
  echo "== 14. cacert.pem beside the exe, directory name not representable in the ANSI code page"
  UD="$WORK/$(printf '\343\203\206\343\202\271\343\203\210_\343\203\246\343\203\274\343\202\266\343\203\274')"   # テスト_ユーザー
  mkdir -p "$UD"
  cp "$PELLEGRINO_EXE_DIR"/pellegrino.exe "$PELLEGRINO_EXE_DIR"/*.dll "$UD"/
  cp good.pem "$UD/cacert.pem"
  rm -f pellegrino.log pellegrino.out.log pellegrino.err.log
  # cwd ($WORK, where the log lands) is NOT the exe's directory, and there is no SSL_CERT_FILE at all:
  # the only way to trust good.pem is the cacert.pem beside the exe
  env -u SSL_CERT_FILE LC_ALL=C.UTF-8 xvfb-run -a "$PELLEGRINO_WINE" "$UD/pellegrino.exe" \
      "--smoke-url=https://localhost:$TLSPORT/index.html"
  for n in "tls TLSv1" "http status=200"; do need "$n"; done
  absent "tls FAILED"
fi

echo "smoke OK"
