# Changelog

## 2026-10-15 (v1.4 -- flexbox, the cheap kind)
- `display: flex` lays a container's block children out as equal-width columns side by side (`gap` / `column-gap`
  honoured; `flex-direction: column` falls back to normal stacking). The child count is scanned ahead in the bytes
  revealed so far, so the columns re-divide as more children stream in. Height = the tallest column.
- One flex level at a time (a flex inside a flex child is laid out as a plain block). Children's own `width` is
  respected inside their column; no wrap/grow/shrink/basis/justify/align.
- Verified by eye in an Xvfb screenshot only; the Bazel smoke suite was not run on this box.

## 2026-10-15 (v1.3 -- box model: width, max-width, auto margins)
- `width` / `max-width` (px, em, % of the parent's content width; content-box, clamped to the parent) and
  `margin-left/right: auto` / `margin: 0 auto` centring. Children now wrap at the parent's content edge
  (parent padding + border respected). Still re-laid-out every frame: it shifts as bytes land, on purpose.
- Verified by eye in an Xvfb screenshot (400px box, 50% centred, max-width cap, nested %); not in the smoke suite
  (it asserts logs, not pixels), and the Bazel suite was not run on this box.

## 2026-10-15 (v1.2 -- CSS-lite, box model, headings, markdown)
- **CSS-lite**: `<style>` rules (tag/.class/#id/*), inline `style=`, `<font color>`/`bgcolor`; hex (`#rgb`/`#rrggbb`),
  `rgb()` and 23 named colors; `color`, `background`, `font-size`, `font-weight`, `display`, `margin`, `padding`, `border`.
- **Box model** on block elements (margin / border / padding, block backgrounds); **h1-h6** at distinct sizes.
- **Markdown** for `.md`/`.markdown` URLs and file arguments, rendered through the same style stack as HTML;
  `[text](url)` are real, Tab-selectable links.
- **F12 / X** toggle CSS, **F11 / P** toggle markdown. Layout shifts as bytes stream in are intentional.
- Layout cursor is now pixel-based (variable glyph scale); the page pass is re-run each dirty frame.
- PARENA@f3fb1bc: runtime slots 32 -> 1024 (`PARENA_SLOTS`); pin bumped. Smoke hooks `--smoke-toggle=`; section 17.

## 2026-10-15 (v1.1 — hypertext)
- **Keyboard link selection:** Tab / Shift+Tab cycle links (wrapping, inverse-blue highlight, scrolled into view),
  Enter or Space follow the selected link. Selection resets on navigation. Smoke hook `--smoke-tab=URL`, section 16.
- **Links are clickable.** `<a href="..">` text is blue + underlined; a left click navigates. Targets resolve
  absolute / `/root` / `//host` / directory-relative against the current URL; `#frag` and non-http schemes are ignored.
- The href is copied out of the stream buffer before navigating (start-nav resets that buffer).
- New smoke hook `--smoke-click=URL` (synthetic click on the first cell at frame 60) and smoke section 15.
- Verified locally with a TLS-less build against a local server; the full suite (needs mbedTLS/Bazel) not run on this box.

## 2026-10-14 (v0.4 — HTTPS)
- **HTTPS**: `https://` URLs and http->https redirects work. mbedTLS 3.6.7 (pinned by sha256, built from
  source with a static-heap user config: no malloc), TLS 1.3 + 1.2, chain **and hostname always verified**;
  a rejected certificate shows a "certificate rejected" page with the reason and nothing is rendered.
  Trust roots: `SSL_CERT_FILE` (unreadable = fail closed), system bundle, else `cacert.pem` beside the exe.
- Releases now ship `cacert.pem` in both bundles (the runner's ca-certificates bundle; the only trust store on Windows).
- `Host:` header includes the port when it is not the scheme default; protocol-relative `//host/..` redirects.
- Fixed: the socket-slot started at 0 instead of -1, so a run with no URL pulled from and closed fd 0.
- Smoke suite extended (trusted, large multi-record body, untrusted cert, wrong hostname, unreadable bundle,
  http->https redirect); also run against the cross-compiled exe under Wine (new non-gating `windows-smoke` CI job).
- Windows packaging compiles the pinned mbedTLS with mingw (`scripts/fetch_mbedtls.sh`, sha256-verified).
- PARENA: `stream-connect-tls` & friends @d3e274b (`make test-net-stream`, `make test-net-stream-tls`).
- Hardening from an adversarial multi-lens review (each item reproduced before it was fixed):
  - navigating away from a page that is still streaming now closes that socket / TLS session (it leaked
    one fd per abandoned navigation, and left the TLS session running);
  - TLS handles are tagged + generational, so a closed/superseded handle can no longer close, read or
    write an unrelated descriptor that reused its number;
  - the TLS handshake and TCP connect run against a monotonic wall-clock deadline (a peer dripping one
    byte per 50 ms used to hold the window frozen indefinitely) and survive EINTR;
  - `cacert.pem` is no longer picked up from the current directory (only beside the executable);
  - a TLS stream that ends without close_notify is flagged in the status bar and log as possibly truncated;
  - `FD_SET` range guards in the runtime.
  Smoke suite: +3 scenarios (navigate-away leak check via the new `--smoke-nav="A B"` self-test hook, TLS
  clean close not flagged, TLS truncation flagged); PARENA `test-net-stream-tls` +8 cases.

## 2026-10-14 (v1)
- Live HTTP: `pellegrino http://...` / `:` address bar; streaming paint, header parse, redirects, title/script/
  style skipped, tint only while bytes are arriving. Windows via winsock2 (`-lws2_32`).
- PARENA: `stdlib/net/stream.prn` (cross-platform TCP client streaming, linebuf, slots) @0f325c5.
- Smoke test now covers embedded page, live HTTP (local server), redirect, and https-not-supported.

## 2026-10-14
- v0: borderless SDL2 streaming text renderer in pure PARENA (`pellegrino.prn`) + slim C host
  (`pellegrino_host.c`); built `-DPARENA_NO_MALLOC`; embedded 5x8 bitmap font; file or embedded page source.
- Logs written to real files next to the executable (`pellegrino.log`, `.out.log`, `.err.log`).
- Bazel build (`MODULE.bazel`, `BUILD.bazel`), headless smoke test.
- CI + auto-release from day 1 (`.github/workflows/ci.yml`): Linux bundle (binary + libSDL2 + RUN.sh), flat
  Windows zip (exe + SDL2.dll + RUN.bat), CONSTRUCT, auto-tag + GitHub Release, Pages deploy for `site/`.
- Landing page (`site/index.html`).
- Founding conversation ingested (`docs/source`, `docs/transcript`, `docs/DESIGN_DIGEST.md`); NORTHSTAR.
- PARENA: `sdl2/create-window-borderless`, `-DPARENA_NO_TTF` (PARENA@523d36e).
