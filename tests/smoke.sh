#!/usr/bin/env bash
# Runs pellegrino under Xvfb in a scratch dir and asserts on the text log it leaves behind:
#   1. --smoke                      embedded page
#   2. --smoke-url=http://127.0.0.1 live HTTP fetch from a local python server (streams, headers, body)
#   3. --smoke-url=<301 redirect>   follows a redirect
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pellegrino"
[ -x "$BIN" ] || BIN="$TEST_SRCDIR/${TEST_WORKSPACE:-_main}/pellegrino"
WORK="$(mktemp -d)"
cleanup() { [ -n "${SRV:-}" ] && kill "$SRV" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT
cd "$WORK"

need() { grep -q "$1" pellegrino.log || { echo "FAIL: '$1' missing from pellegrino.log"; cat pellegrino.log; exit 1; }; }
run() { rm -f pellegrino.log pellegrino.out.log pellegrino.err.log; xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" "$@"; }

echo "== 1. embedded page"
run --smoke
for n in "pellegrino v1 start" "source bytes=" "window+renderer up" "smoke limit reached" "clean exit"; do need "$n"; done

echo "== 2. live HTTP"
mkdir www && printf '<html><body><h1>hello from the wire</h1><p>streamed over plain http</p></body></html>\n' > www/index.html
PORT=$((20000 + RANDOM % 20000))
python3 - "$PORT" <<'PY' &
import http.server, socketserver, sys, os
os.chdir("www")
class H(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    def do_GET(self):
        if self.path == "/old":
            self.send_response(301); self.send_header("Location", "/index.html"); self.end_headers(); return
        return super().do_GET()
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
SRV=$!
for _ in $(seq 1 50); do (echo > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && break; sleep 0.1; done
run "--smoke-url=http://127.0.0.1:$PORT/index.html"
for n in "navigate http://127.0.0.1:$PORT/index.html" "connected; fd=" "http status=200" "stream closed; bytes=" "clean exit"; do need "$n"; done

echo "== 3. redirect"
run "--smoke-url=http://127.0.0.1:$PORT/old"
for n in "http status=301" "navigate http://127.0.0.1:$PORT/index.html" "http status=200" "clean exit"; do need "$n"; done

echo "== 4. https is reported, not crashed"
run "--smoke-url=https://example.com/"
for n in "https not supported yet" "clean exit"; do need "$n"; done

echo "smoke OK"
