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
#  15. hypertext                      <a href> clicks: root-relative, directory-relative, and the ignored kinds
#                                      (#fragment, mailto:)
#  16. keyboard links                 Tab / Shift+Tab move the selection, Enter/Space follow it
#  17. css / markdown                 <style> rules are collected, F12/X and F11/P toggle css and markdown
#  18. images                         <img src=x.png> is fetched, decoded and stored once the page stream closed;
#                                      a missing file and a non-PNG fail honestly (placeholder, no crash)
#  19. forms, entities, keys         <form> GET and POST (urlencoded body reaches the server), &amp;/&quot;/curly
#                                      quotes, PageUp/PageDown/Home/End, Shift+J/K/L/I window move
#  20. css3, asynchronously          <link rel=stylesheet> and @import are fetched after the page has painted (the
#                                      first pass has only the inline rules); when they land the whole page is
#                                      restyled (layout shift); @media, var(), selectors, !important; hostile
#                                      sheets (huge, cyclic, malformed, junk, missing, refused) never crash it
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

echo "== 15. hypertext: clicking a link navigates (synthetic click on the page's first cell)"
mkdir -p www/dir
printf '<a href="/index.html">root-relative</a> then some text\n' > www/link_abs.html
printf '<a href="sib.html">dir-relative</a>\n' > www/dir/link_rel.html
printf '<p>sibling arrived</p>\n' > www/dir/sib.html
printf '<a href="mailto:a@b.example">mail</a>\n' > www/link_mail.html
printf '<a href="#top">frag</a>\n' > www/link_frag.html
run "--smoke-click=http://127.0.0.1:$PORT/link_abs.html"
for n in "smoke-click:" "link click: http://127.0.0.1:$PORT/index.html" "navigate http://127.0.0.1:$PORT/index.html" "clean exit"; do need "$n"; done
run "--smoke-click=http://127.0.0.1:$PORT/dir/link_rel.html"
for n in "link click: http://127.0.0.1:$PORT/dir/sib.html" "navigate http://127.0.0.1:$PORT/dir/sib.html" "clean exit"; do need "$n"; done
for f in link_mail link_frag; do
  run "--smoke-click=http://127.0.0.1:$PORT/$f.html"
  need "smoke-click:"; need "clean exit"
  absent "link click:"   # not navigable: ignored, the page stays put
  [ "$(grep -c '^navigate ' pellegrino.log)" -eq 1 ] || { echo "FAIL: $f navigated"; cat pellegrino.log; exit 1; }
done

echo "== 16. keyboard link selection (synthetic Tab, Tab, Shift+Tab, Enter)"
printf '<a href="/index.html">one</a> <a href="/dir/sib.html">two</a>\n' > www/link_tabs.html
run "--smoke-tab=http://127.0.0.1:$PORT/link_tabs.html"
for n in "smoke-tab: next link" "smoke-tab: previous link" "smoke-enter:" "link click: http://127.0.0.1:$PORT/index.html" "clean exit"; do need "$n"; done
absent "link click: http://127.0.0.1:$PORT/dir/sib.html"   # Tab,Tab,Shift+Tab lands on the FIRST link

echo "== 17. css rules are collected; css and markdown toggle (synthetic X, P, X)"
cat > www/styled.html <<'HTML'
<html><head><style>
body { background: #101820; color: #cfe8ff }
h1, .card { color: #f00; padding: 8px; border: 1px solid red }
#gone { display: none }
</style></head><body><h1>Title</h1><div class="card" style="margin: 10px">box</div><p id="gone">hidden</p></body></html>
HTML
printf '[go](/index.html) then **bold**\n\n# Heading\n' > www/doc.md
run "--smoke-toggle=http://127.0.0.1:$PORT/styled.html"
for n in "css: rules=4" "css: off" "css: rules=0" "markdown: off" "css: on" "clean exit"; do need "$n"; done
run "--smoke-click=http://127.0.0.1:$PORT/doc.md"
for n in "smoke-click:" "link click: http://127.0.0.1:$PORT/index.html" "clean exit"; do need "$n"; done   # a markdown [link](url) is a real link

echo "== 18. <img>: PNG decoded and stored; a 404 and a JPEG fail honestly"
python3 - <<'PY'
import struct, zlib
def png(w, h, rgb):
    raw = b"".join(b"\x00" + bytes(rgb) * w for _ in range(h))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open("www/red.png", "wb").write(png(20, 10, (255, 0, 0)))
open("www/fake.jpg", "wb").write(b"\xff\xd8\xff\xe0 not a png")
open("www/pics.html", "w").write('<p>a<img src="red.png" alt="red"> b<img src="/gone.png" alt="gone"> c<img src="fake.jpg" alt="jpg"> d</p>\n')
PY
run "--smoke-url=http://127.0.0.1:$PORT/pics.html"
for n in "img: loaded http://127.0.0.1:$PORT/red.png 20" "img: failed http://127.0.0.1:$PORT/gone.png" "img: failed http://127.0.0.1:$PORT/fake.jpg" "clean exit"; do need "$n"; done

echo "== 19. forms: a synthetic click focuses the field, text is typed, Enter submits (GET and POST)"
printf '<form action="/index.html" method="get"><input name="q" value="pre"><input type="hidden" name="h" value="a b&amp;c"><input type="checkbox" name="c" checked><input type="submit" name="go" value="Go"></form>\n' > www/form_get.html
printf '<form action="/submit" method="post"><input name="p" value="x"><input type="hidden" name="h" value="a b"><input type="submit" name="go" value="Go"></form>\n' > www/form_post.html
run "--smoke-form=http://127.0.0.1:$PORT/form_get.html"
for n in "smoke-form: typing" "navigate http://127.0.0.1:$PORT/index.html?q=prehello+world+%26+co&h=a+b%26c&c=on" "clean exit"; do need "$n"; done
rm -f www/post.log
run "--smoke-form=http://127.0.0.1:$PORT/form_post.html"
need "form: POST http://127.0.0.1:$PORT/submit"
grep -q '^/submit p=xhello+world+%26+co&h=a+b$' www/post.log || { echo "FAIL: POST body wrong"; cat www/post.log; exit 1; }
echo "== 19c. <select> and <textarea> submit their value (the chosen <option>, the seeded text)"
printf '<form action="/index.html" method="get"><input name="q" value=""><select name="c"><option value="r">Red</option><option value="g" selected>Green</option></select><textarea name="t">note one</textarea><input type="submit" name="go" value="Go"></form>\n' > www/form_sel.html
run "--smoke-form=http://127.0.0.1:$PORT/form_sel.html"
for n in "smoke-form: typing" "navigate http://127.0.0.1:$PORT/index.html?q=hello+world+%26+co&c=g&t=note+one" "clean exit"; do need "$n"; done
echo "== 19b. entities and curly quotes decode; scroll keys; window move"
python3 - > www/long.html <<'PY'
print("<p>Tom &amp; Jerry &lt;3 &#65;&#x42; \u201cq\u201d \u2014 done</p>")
for i in range(150):
    print("<p>row %d</p>" % i)
PY
run "--smoke-keys=http://127.0.0.1:$PORT/long.html"
for n in "smoke-keys: scroll=0" "clean exit"; do need "$n"; done
grep -q 'smoke-keys: scroll=[1-9]' pellegrino.log || { echo "FAIL: PageDown did not scroll"; cat pellegrino.log; exit 1; }
run "--smoke-move=http://127.0.0.1:$PORT/index.html"
[ "$(grep -c '^window: move' pellegrino.log)" -eq 2 ] || { echo "FAIL: window did not move"; cat pellegrino.log; exit 1; }

echo "== 20. css3: external sheets arrive after the first paint and restyle the page"
cat > www/async.html <<'HTML'
<html><head>
<link rel="stylesheet" href="/slow/ext.css">
<style>@import url("/slow/imp.css"); p { color: #00ff00 }</style>
</head><body>
<h1>Async sheet</h1>
<p class="note">note text</p>
<div class="box"><p>inner plain</p><span id="s">span</span></div>
<ul><li>one</li><li>two</li><li>three</li><li>four</li></ul>
<a href="/x" title="t">link</a>
</body></html>
HTML
cat > www/ext.css <<'CSS'
:root { --accent: #ff0000; --pad: 8px; }
h1 { color: hsl(200, 100%, 50%); text-transform: uppercase; }
.note { color: var(--accent); padding: var(--pad); border: 1px solid var(--accent); }
.box > p { color: rgba(255, 255, 0, 1); }
.box span#s { background-color: #ff00ff; color: #fff; }
li:nth-child(odd) { color: #ffa500; }
li:first-child { text-decoration: underline; }
@media (max-width: 600px) { .note { color: #0000ff; } }
@media (min-width: 800px) { ul { background: #223344; } }
a[title] { color: #ff69b4 !important; }
a { color: #123456; }
CSS
printf '.box { background: #333333; padding: 4px; }\n' > www/imp.css
run "--smoke-keys=http://127.0.0.1:$PORT/async.html"
for n in "css: rules=1" "css: fetch http://127.0.0.1:$PORT/slow/ext.css" "css: loaded [0-9]* bytes http://127.0.0.1:$PORT/slow/ext.css" \
         "css: fetch http://127.0.0.1:$PORT/slow/imp.css" "css: loaded 44 bytes http://127.0.0.1:$PORT/slow/imp.css" "clean exit"; do need "$n"; done
# order is the whole point: painted with the inline rule only, the sheet arrives later, the page restyles after
line_of() { grep -n -- "$1" pellegrino.log | head -1 | cut -d: -f1; }
a=$(line_of "css: rules=1$"); b=$(line_of "css: loaded"); c=$(line_of "css: rules=11$")
[ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] || { echo "FAIL: sheets did not arrive after the first pass"; cat pellegrino.log; exit 1; }
absent "css: failed"
# the max-width media rule never counts: 1 inline + 10 from ext.css, then +1 from the @import
need "css: rules=12"

echo "== 20c. UA default styling: margins collapse, whitespace collapses, author resets win"
last_rows() { grep -o 'page: rows=[0-9]*' pellegrino.log | tail -1 | sed 's/.*=//'; }
printf '<html><body><h1>T</h1><p>a</p><p>b</p><ul><li>x<ul><li>y</li></ul></li></ul><p>c</p></body></html>' > www/ua_min.html
cat > www/ua_ws.html <<'HTML'
<!doctype html>
<html>
  <body>
    <h1>T</h1>
    <p>a</p>
    <p>
       b
    </p>
    <ul>
      <li>x
        <ul>
          <li>y</li>
        </ul>
      </li>
    </ul>
    <p>c</p>
  </body>
</html>
HTML
printf '<html><head><style>* { margin: 0; padding: 0 }</style></head><body><h1>T</h1><p>a</p><p>b</p><ul><li>x<ul><li>y</li></ul></li></ul><p>c</p></body></html>' > www/ua_reset.html
run "--smoke-keys=http://127.0.0.1:$PORT/ua_min.html"; need "clean exit"; r_min=$(last_rows)
run "--smoke-keys=http://127.0.0.1:$PORT/ua_ws.html"; need "clean exit"; r_ws=$(last_rows)
run "--smoke-keys=http://127.0.0.1:$PORT/ua_reset.html"; need "clean exit"; r_reset=$(last_rows)
echo "rows: minified=$r_min whitespace=$r_ws reset=$r_reset"
[ -n "$r_min" ] && [ "$r_min" = "$r_ws" ] || { echo "FAIL: source whitespace changed the layout ($r_min vs $r_ws)"; exit 1; }
[ -n "$r_reset" ] && [ "$r_reset" -lt "$r_min" ] || { echo "FAIL: a margin reset did not tighten the page ($r_reset vs $r_min)"; exit 1; }
[ "$r_min" = "13" ] || { echo "FAIL: default margins drifted: rows=$r_min, expected 13"; exit 1; }
[ "$r_reset" = "7" ] || { echo "FAIL: reset layout drifted: rows=$r_reset, expected 7"; exit 1; }

echo "== 20b. css3: hostile sheets do not crash it"
python3 - <<'PYEND'
import random
random.seed(7)
open("www/big.css", "w").write("".join(".c%d{color:#%06x;margin:%dpx}\n" % (i, random.randrange(1 << 24), i % 40) for i in range(12000)))
open("www/cyc_a.css", "w").write('@import url("cyc_b.css");\n.cyca{color:#0f0}\n')
open("www/cyc_b.css", "w").write('@import "cyc_a.css";\n.cycb{color:#0f0}\n')
open("www/bad.css", "w").write("""@media (min-width: {  .x{color:red}
.y{color:var(--a};
:root{--a:var(--b);--b:var(--a)}
.z{color:var(--a);width:calc(1px + );margin:calc(((}
@import ;
@import url(;
a[ {color:red}
a:nth-child( {color:red}
:not( {color:red}
.w{width:calc(100%/0);font:;border-left:;background:rgba(;color:hsl(}
}}}}
/* unterminated comment
.q{color:red}""")
open("www/junk.css", "wb").write(bytes(random.randrange(32, 127) for _ in range(5000)))
open("www/robust.html", "w").write("""<html><head>
<link rel="stylesheet" href="/big.css"><link rel="stylesheet" href="cyc_a.css"><link rel=stylesheet href=bad.css>
<link rel="stylesheet" href="junk.css"><link rel="stylesheet" href="missing.css"><link rel="stylesheet" href="http://127.0.0.1:1/x.css">
<link rel="stylesheet" href="/old"><link rel="stylesheet" media="print" href="never.css"><link rel="alternate stylesheet" href="alt.css">
</head><body><div class="c5 cyca q z">robust</div></body></html>""")
PYEND
run "--smoke-keys=http://127.0.0.1:$PORT/robust.html"
for n in "css: loaded 98304 bytes http://127.0.0.1:$PORT/big.css" "css: rules=160" "css: loaded 335 bytes http://127.0.0.1:$PORT/bad.css" \
         "css: failed http://127.0.0.1:$PORT/missing.css" "css: failed http://127.0.0.1:1/x.css" "clean exit"; do need "$n"; done
absent "never.css"
absent "alt.css"
if [ -s pellegrino.err.log ] && grep -q "out of memory" pellegrino.err.log; then echo "FAIL: out of memory"; cat pellegrino.err.log; exit 1; fi

# ---- HTTP/3 (QUIC) ------------------------------------------------------------------------------------
# Needs aioquic (pip install aioquic) as the independent HTTP/3 server; skipped, loudly, when missing.
if python3 -c "import aioquic" 2>/dev/null; then
  H3SERVER="$HERE/smoke_h3_server.py"
  [ -f "$H3SERVER" ] || H3SERVER="${TEST_SRCDIR:-}/${TEST_WORKSPACE:-_main}/tests/smoke_h3_server.py"
  H3PORT=$(free_port)
  python3 "$H3SERVER" "$H3PORT" www good.pem good.key > h3server.out 2>&1 & PIDS+=($!)
  for _ in $(seq 1 80); do grep -q READY h3server.out 2>/dev/null && break; sleep 0.1; done
  grep -q READY h3server.out || { echo "h3 server did not start"; cat h3server.out; exit 1; }

  echo "== 21. h3:// explicit HTTP/3 (QUIC + TLS 1.3 in PARENA, certificate verified)"
  SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=h3://localhost:$H3PORT/index.html"
  for n in "navigate h3://localhost:$H3PORT/index.html" "h3: connecting localhost:$H3PORT" "h3 ok; bytes=" "http status=200" "clean exit"; do need "$n"; done
  absent "connected; fd="
  absent "tls TLSv1"
  absent "h3 FAILED"

  echo "== 21b. h3://: a redirect is followed over HTTP/3"
  SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=h3://localhost:$H3PORT/old"
  for n in "http status=301" "http status=200" "clean exit"; do need "$n"; done
  absent "h3 FAILED"

  echo "== 22. h3://: an untrusted certificate is refused, nothing rendered"
  SSL_CERT_FILE="$WORK/other.pem" run "--smoke-url=h3://localhost:$H3PORT/index.html"
  for n in "h3 FAILED status=-3" "clean exit"; do need "$n"; done
  absent "http status="
  absent "falling back"

  echo "== 22b. h3://: a wrong host name is refused"
  SSL_CERT_FILE="$WORK/wrong.pem" run "--smoke-url=h3://localhost:$H3PORT/index.html"
  for n in "h3 FAILED status=-3" "clean exit"; do need "$n"; done
  absent "http status="

  echo "== 22c. h3://: a port with no server fails fast with an error page (no 15 s wait)"
  T0=$(date +%s)
  SSL_CERT_FILE="$WORK/good.pem" run "--smoke-url=h3://localhost:$(free_port)/index.html"
  T1=$(date +%s)
  for n in "h3 FAILED status=-6" "clean exit"; do need "$n"; done
  [ $((T1 - T0)) -le 8 ] || { echo "FAIL: refused UDP port took $((T1 - T0)) s"; cat pellegrino.log; exit 1; }

  echo "== 23. Alt-Svc: https:// is upgraded to HTTP/3 after a response advertises it"
  ASPORT=$(free_port)
  serve "$ASPORT" www good.pem good.key --alt-svc "h3=\":$H3PORT\"; ma=86400"
  wait_port "$ASPORT"
  SSL_CERT_FILE="$WORK/good.pem" run "--smoke-nav=https://localhost:$ASPORT/index.html https://localhost:$ASPORT/index.html"
  for n in "tls TLSv1" "alt-svc: h3 port $H3PORT" "h3: connecting localhost:$H3PORT" "h3 ok; bytes=" "clean exit"; do need "$n"; done
  absent "h3 FAILED"

  echo "== 24. Alt-Svc to a dead UDP port falls back to TCP+TLS transparently"
  DEADPORT=$(free_port)
  FBPORT=$(free_port)
  serve "$FBPORT" www good.pem good.key --alt-svc "h3=\":$DEADPORT\"; ma=86400"
  wait_port "$FBPORT"
  SSL_CERT_FILE="$WORK/good.pem" run "--smoke-nav=https://localhost:$FBPORT/index.html https://localhost:$FBPORT/index.html"
  for n in "alt-svc: h3 port $DEADPORT" "h3: connecting localhost:$DEADPORT" "h3 FAILED status=-6" "falling back to TCP+TLS" "http status=200" "clean exit"; do need "$n"; done
else
  echo "== 21-24. HTTP/3 SKIPPED: python3 aioquic is not importable (pip install aioquic)"
fi

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
