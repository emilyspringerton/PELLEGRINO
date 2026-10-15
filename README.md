![PELLEGRINO Logo](logo.jpg)

# PELLEGRINO

all gas; no brakes; powered by PARENA
*"Do not confuse momentum with permission."*
With <4 from america

**CLEAN BUILDS FIRST**

A web browser and terminal shell stripped to essentials: no defensive layers, no garbage collection, no
`malloc`. Written in [PARENA](https://github.com/emilyspringerton/PARENA) with a slim C host. Public domain
(The Unlicense). Landing page: [`site/`](site/index.html).

## Status — v1 + HTTPS (honest)

**Works today**
- Borderless SDL2 window (1280x720) that streams a page onto the glass: tags stripped, drifting-cursor
  layout, embedded 5x8 bitmap font, newest bytes tinted amber, a loading-horizon line at the stream front.
- **Live HTTP and HTTPS**: `pellegrino https://host/path` — or press `:` in the window, type a URL, Enter.
  A TCP connection (BSD sockets / winsock2) streams the body onto the glass as bytes land; headers are
  parsed, 301/302/303/307/308 redirects followed (max 5, http<->https included), `<title>/<script>/<style>`
  content skipped.
- **TLS is real and not optional**: `https://` goes through mbedTLS (pinned 3.6 LTS, TLS 1.3 + 1.2),
  and the certificate chain **and hostname are always verified** — there is no switch to turn it off.
  A bad certificate shows a "certificate rejected" page with the reason and renders nothing. mbedTLS
  allocates from one static buffer (2 MiB, BSS), so the no-malloc claim holds for TLS too. Trust roots:
  `SSL_CERT_FILE` if set (unreadable = fail closed, no fallback), else the system bundle, else the
  `cacert.pem` shipped next to the executable (the only store on Windows) — never the current directory.
  A TLS stream that ends without a close_notify (possible truncation) is flagged in the status bar and the
  log instead of being presented as a complete page; navigating away closes the stream being left.
- Source = live URL, embedded page (default), or a file path: `pellegrino path/to/page.html`.
- Keys: `:` address bar, Up/Down/PageUp/PageDown/Home/End or mouse wheel to scroll, Shift+J/L/I/K move the window, Esc/q to quit.
- **No malloc**: the PARENA runtime is built with `-DPARENA_NO_MALLOC` (static pool); the C host is `main()`
  and log redirection only (`pellegrino_host.c`, ~25 lines).
- **Real log files**: `pellegrino.log` (engine), `pellegrino.out.log`, `pellegrino.err.log` next to the
  executable — the Windows build is a windowed (no-console) exe, so nothing lives only in a terminal that
  flashes and closes.
- Bazel build (`bazelisk build //:pellegrino`), headless smoke test under Xvfb (`bazelisk test //...`):
  embedded page, live HTTP, redirect, HTTPS with a trusted / untrusted / wrong-hostname certificate,
  an unreadable bundle, http->https redirect, navigating away mid-stream (no socket/TLS leak), TLS clean
  close vs truncation. The same suite also passes against the cross-compiled `pellegrino.exe` under Wine.
- CI from day 1: every green push to `main` auto-tags a MINOR version and publishes a GitHub Release with
  a Linux bundle (binary + bundled libSDL2 + `cacert.pem` + `RUN.sh`) and a flat Windows zip
  (`pellegrino.exe` + `SDL2.dll` + `cacert.pem` + `RUN.bat`), plus a deterministic CONSTRUCT source snapshot.

- **Hypertext (v1.1):** `<a href>` text is drawn blue + underlined and a left click navigates (absolute,
  root-relative, `//host`, and directory-relative targets). `#fragment` and non-http schemes (`mailto:`,
  `javascript:`) are ignored. **Keyboard:** Tab / Shift+Tab select the next / previous link (wraps; the
  selected link is drawn as an inverse blue bar and scrolled into view), Enter or Space follows it. Not yet:
  `../` dot-segment normalisation (left to the server), link hover/cursor, back/forward history, `<base href>`, `target=`. Hit-testing is cell-based and the
  link colour is not yet verified by eye (no screenshot tool on the build box).

- **CSS-lite, box model, headings, markdown (v1.2):** see the table below. Everything is re-laid-out from the
  first byte on every dirty frame, so rules and tags apply the instant their bytes land and the page *shifts*
  as it streams (by design). **F12 or `x`** toggles author CSS; **F11 or `p`** toggles markdown rendering
  (the status bar shows `css:on md:on`). With CSS off the UA defaults stay (h1-h6 sizes, link blue, bold/code),
  like a browser with author styles disabled.

  | Area | Supported | Not supported |
  |---|---|---|
  | Sources | `<style>` blocks, inline `style=""`, `<font color>`, `bgcolor=` | external stylesheets (`<link>`), `@media`/`@import` (skipped) |
  | Selectors | `tag`, `.class`, `#id`, `*`, comma lists | descendant/child/attribute/pseudo selectors, `tag.class`, specificity (source order wins) |
  | Colors | `#rgb`, `#rrggbb`, `rgb()/rgba()` (alpha ignored), 23 named colors | `hsl()`, the other ~120 CSS names, `currentColor`, transparency |
  | Properties | `color`, `background[-color]`, `font-size` (px/em/%/pt -> 4 glyph sizes), `font-weight`, `display: none/block/inline`, `margin[-side]`, `padding[-side]`, `border` (width + color), `width`, `max-width` (px/em/%, content-box), `display: flex` (row, equal columns) + `gap`, `flex-direction: column` | `height`/`min-*`, floats, `flex-wrap`/`flex-grow`/`flex-basis`/`justify-content`/`align-*`, nested flex, flex/grid, `text-align`, fonts, `border-radius`, per-side borders |
  | Box model | margin / border / padding on block elements; `width`/`max-width` (a % is of the parent's content width, clamped to it); `margin-left/right: auto` (and `margin: 0 auto`) centre or push a fixed-width block; backgrounds fill the block's rows | `height`, margin collapsing, inline-block, tables as tables |
  | Headings | h1-h6 (glyph scale 4,3,2,2,2,1; h1-h3 bold, distinct colors) | |
  | Markdown | `#`..`######`, `- * +` bullets, `>` quote, fenced code, `---`, `**bold**`, `` `code` ``, `[text](url)` (a real, Tab-selectable link) for `.md`/`.markdown` URLs and file arguments | numbered lists, tables, images, `*italic*`/`_italic_`, nested lists, HTML blocks |

  Limits: 64 rules, style stack depth 11, no word-wrap (breaks mid-word at the box edge), one 5x8 bitmap font.
  Verified by eye in a headless (Xvfb) screenshot of a styled page and a markdown file; the smoke suite
  checks rule collection, the toggles and markdown links, not pixels.

- **Images (v1.5):** `<img src>` of an 8-bit non-interlaced **PNG** (RGB, RGBA, palette; decoded by PARENA's own
  `image/png`) is fetched over http/https once the page stream has closed, decoded, and drawn with nearest-neighbour
  scaling (`width=`/`height=` attributes honoured, shrunk to the box, capped at 320 px high; alpha < 128 is skipped,
  no blending). Until it lands the tag shows `[img] alt`; a failure shows `![img] alt`, and the layout shifts when the
  pixels arrive. Limits: 2048 px a side and 262144 pixels, 2 MiB file, 24 images per page, one fetch per frame and
  each one is synchronous (up to ~3 s of silence while it runs), http(s) pages only (not file arguments), no JPEG/GIF/
  WebP/SVG, no CSS `background-image`, images are not links-aware (a click on one is just a click). Verified live
  over plain HTTP with RGBA/RGB/palette fixtures and a screenshot; the HTTPS image path is the same code behind
  `stream-connect-tls` but was not exercised on this box (no mbedTLS dev).

- **Forms, entities, keys (v1.6):** `<form>` with text/password/hidden/checkbox/radio/submit `<input>` and `<button>`;
  click to focus, type, Enter or a button submits as **GET** (query string) or **POST**
  (`application/x-www-form-urlencoded` body). Limits: 24 controls, 32-byte values, ~1000 bytes encoded, no `<textarea>`/
  `<select>`/file/validation/multipart, one line per control. HTML entities and curly quotes/dashes decode to ASCII
  look-alikes. **PageUp/PageDown/Home/End** scroll (End = the last screen); **Shift+J/L/I/K** move the window
  (48 px). `<html>`/`<body>` styling (background, color, margin, padding, border, width) works; the canvas takes
  `<html>`'s background, else `<body>`'s. Verified live over plain HTTP under Xvfb; the HTTPS form path is the same
  code but untested here.

**Not built yet** (see [NORTHSTAR.md](NORTHSTAR.md))
- HTTP/1.0 only (no chunked/keep-alive/compression), HTTP/2, HTTP/3/QUIC (mbedTLS has no QUIC hooks, so
  that rung needs its own TLS answer), other image formats, fonts beyond the embedded bitmap
  font. DNS, connect and the TLS handshake are blocking (5 s connect timeout, 10 s handshake cap), so the
  window does not repaint while one is in flight. No session resumption, no OCSP/CRL revocation checks.
- The Windows exe is verified under Wine (winsock, bcrypt entropy, mbedTLS static heap all exercised), not
  yet on a physical Windows machine.
- The terminal (ANSI/SSH) viewport and the terminal-to-SDL2 hot-swap.
- Any measured performance numbers: the page says "minimal / 0 ms / compact" on purpose — nothing here has
  been benchmarked yet and no figure should be quoted until a harness exists.
- **Safety:** no sandbox, no process isolation. Trusted content only.

## Run

Download the latest release, unzip, and run `RUN.bat` (Windows) or `./RUN.sh` (Linux). Pass a URL as the first argument, or
`--smoke` / `--smoke-url=https://...` / `--smoke-nav="A B"` (load A, then submit B through the address-bar
path) for a self-exiting run (used by the CI smoke test). Check `pellegrino.log` next to the
executable. `SSL_CERT_FILE=/path/to/bundle.pem` overrides the trust roots (e.g. for a private CA).

## Build

```bash
bazelisk build //:pellegrino      # needs libsdl2-dev; fetches + builds the pinned mbedTLS itself
bazelisk test //...               # headless smoke (needs xvfb, openssl, python3)
bash scripts/package_linux.sh     # dist/pellegrino_linux_x86_64.zip
SDL2_MINGW=/path/to/SDL2/x86_64-w64-mingw32 bash scripts/package_windows.sh   # dist/pellegrino_windows.zip
                                  # (mingw-w64; downloads + sha256-verifies the same mbedTLS pin and compiles it)
```

PARENA is pinned by commit in `MODULE.bazel`; to build against a sibling checkout add
`--override_module=parena=../PARENA`.

## Layout

| Path | What |
|---|---|
| `pellegrino.prn` | the engine (PARENA) |
| `pellegrino_host.c` | slim C harness: `main()` + log redirection |
| (PARENA) `stdlib/net/stream.prn` | the cross-platform TCP + TLS streaming primitive this engine stands on |
| `third_party/mbedtls/` | pinned mbedTLS release, its user config (static heap), and the Bazel build rule |
| `tests/smoke.sh`, `tests/smoke_server.py` | headless end-to-end suite (local HTTP + HTTPS fixture servers) |
| `tools/gen_font.py` | generates the embedded 5x8 font table |
| `site/` | landing page |
| `docs/` | founding conversation (raw + transcript), digest |
| `NORTHSTAR.md` | what this is and where it goes |
