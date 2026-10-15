# Changelog

## 2026-10-15 (CI fix, kanban #642)
- Fixed the red build (5 consecutive failing `main` runs since the v1.11 embed API): `MODULE.bazel` still pinned
  PARENA `86bb47c`, but the embed code calls `sdl2-raw-create-surface-renderer` / `sdl2_create_surface_renderer_impl`,
  which only exist from PARENA `aa48abf`. At the old pin the generated C had an implicit declaration and failed to
  link on both the Linux and Windows jobs. Pin bumped to `aa48abf`. Verified locally by regenerating
  `pellegrino_gen.inc` from the new stdlib and syntax-checking the host against the new runtime (clean), and by
  reproducing the failure against the old pin's stdlib/runtime. The full Bazel build/test could not be run here
  (no Bazel on this box) -- CI is the proof. (session: unknown)

## 2026-10-15 (v1.12 -- dogfooding MIXFORGE, kanban #637)
- Rendered MIXFORGE's `web/dj.html` and `web/multiplayer.html` (file argument, headless Xvfb screenshots) and fixed what broke:
  - **A `<script>` body no longer leaks onto the page.** Skipped content ended at the first `</` of any kind, so a
    template literal containing `</div>` dumped the rest of the script as text. It now ends only at `</script`,
    `</style` or `</title` (either case). Regression check in `tests/embed_test.c`.
  - **Word wrap.** Paragraphs broke mid-word ("compu|ted"). Before a word's first character in an HTML document the
    line breaks if the whole word will not fit and a fresh line would hold it; a collapsed space that would start a
    line is the break (no leading space). `<pre>`, plain text and markdown keep the old per-character wrap.
  - UTF-8 `±`, `°`, `²`, `³`, `µ`, `÷` render as ASCII look-alikes instead of `?`.
- Still not working on those pages, by design of the pages: the decks/pads are built by JavaScript at load time, and
  PELLEGRINO has no JS yet (PARENA's `stdlib/v16` engine exists but is not wired in). `<input type=range>` shows as a
  text box with its value. Verified by eye in screenshots only; the full Bazel smoke suite was NOT re-run.

## 2026-10-15 (v1.11 -- embed API)
- Kanban #627 (SHANKPIT OS menu on basic HTML/CSS + PELLEGRINO rendering). `pellegrino.prn` gains an **embed API**
  so a host that owns its own window/event loop can use the layout + paint engine as a library: `embed-open w h`
  (offscreen ARGB8888 software renderer, needs PARENA aa48abf+), `embed-draw ren page n w h clear`, `embed-click`,
  `embed-wheel`, `embed-key` (Tab/Shift+Tab/Enter/Space), `embed-action-start`/`-end` (the activated link's byte range
  INTO THE HOST'S OWN PAGE STRING -- embed mode never navigates, so `shankpit:` etc. schemes are the host's) and
  `embed-ack`. Slots 4000-4002. `tests/embed_test.c` + `scripts/embed_test.sh`: 9 checks (paint, click -> href range,
  ack, Tab+Enter) under `SDL_VIDEODRIVER=dummy`. The browser path (`pellegrino-run`) is untouched.
  Not built: Bazel target for the embed test (script only), the full smoke suite was NOT re-run on this change.
- **`text-decoration: none` now removes the link underline** (depth slot 4003, deco kind 22; was parsed and ignored,
  links were always underlined). Found dogfooding the OS menu. Verified by eye in an embed render and a headless
  browser start; no smoke-suite assertion yet.

## 2026-10-15 (v1.10 -- UA default styling)
- Founder real-time: "can we ensure we have some default styling on dom elements? ... in the case where the dev is
  relying on some of the defaults i think those cases are showing weird in places".
- **Default margins** for h1-h6, `p`, `ul`/`ol`/`menu`/`dir` (none when nested in an `li`), `pre`, `blockquote`, `dl`,
  `figure`, plus indents for lists/`dd`/`figure`. Before, only headings had a bottom margin and paragraph gaps came
  from the source newline between tags -- so minified HTML had none and pretty-printed HTML had double.
- **Margins collapse** (adjacent vertical margins take the max); an author `margin` replaces the UA value, so a
  `* { margin: 0 }` reset now removes every gap (the old implicit blank row before a block is gone).
- **HTML whitespace collapsing** in documents (`<!doctype>`/`<html>`/`<body>`): newlines/tabs/space runs are one space
  and disappear at line starts; `<pre>` and markdown line entries keep them. Plain text and markdown pages are
  untouched. A newline right after a block's margin no longer adds a second gap in fragments.
- New log line `page: rows=N` (laid-out height, logged on change); smoke section 20c asserts minified == pretty-printed
  == 13 rows and the reset page == 7.

## 2026-10-15 (v1.9 -- CSS3, asynchronous stylesheets)
- Founder real-time: "ensure we support css3 on an asynchronous basis; remember embrace the layout shifts".
- **External stylesheets, async**: `<link rel=stylesheet>` (quoted or unquoted attributes, `media=`) and `@import` are
  queued while the page is scanned and fetched without blocking a frame (second stream bank, bounded pull batches
  per frame; plain-http sheets while the page streams, https after it ends). The page paints first, restyles from
  byte 0 when a sheet lands (the layout shift), applies sheets in document order. PARENA `86bb47c` adds the static
  stylesheet store (`css-append`/`css-buf`/`css-len`/`css-reset`) and `PARENA_SLOTS` 4096 (pin bumped).
- **Selectors**: descendant, child, compounds, attribute operators, `:first-child`, `:nth-child()`, `:not()`,
  `:is()`/`:where()`, `:root`, `:link`, `:checked`, `:disabled`; specificity ordering + `!important`.
- **Values**: `rgba`/`hsl`/`hsla`/`#rgba`/`#rrggbbaa` with alpha blended over the backdrop, all named colours,
  `calc()`, `var()` + custom properties, `vw vh vmin vmax ch ex in cm mm pc`, font-size keywords, `font`
  shorthand, gradients -> first stop.
- **At-rules**: `@media` (width/height ranges, `and`/`not`/`,`, orientation), `@supports`, `@layer`, `@import`.
- **Properties**: `box-sizing`, `text-transform`, `border-left/-color/-width/-style`, `inline-flex`,
  `background-image`; links take an author `color` (`<a>` is now a real style-stack element).
- Smoke sections 20/20b (async order; hostile sheets); `tests/smoke_server.py` gained `/slow/<file>`. Fixed along
  the way: an `@import`-style statement at-rule used to swallow the next rule; declarations are split paren-aware
  (`url(data:...;base64,..)`).
- Not built: `+`/`~` combinators, `:last-child`, `:hover`, `::before/::after`, `grid`, float/position, `text-align`,
  `opacity`/`border-radius`/`box-shadow`/transforms (parsed and ignored), `var()` in `display`, per-scope custom
  properties. Not run: Bazel, HTTPS sheets (no mbedTLS dev on this box).

## 2026-10-15 (v1.8 -- HTML5 gaps closed)
- `u`/`ins`/`del`/`s`/`strike` and CSS `text-decoration: underline|line-through` draw real lines; `<q>` quote marks;
  `<details>` collapses (unless `open`) and toggles on a click of its `<summary>`; tables align their columns and rule
  off header rows; `<select>` (click cycles, value submitted), `<textarea>` (one-line editable), `<progress>`,
  `<meter>`; `<head>` hidden (and implicitly closed by the first non-head element); a block after bare inline text
  gets its top gap.
- Fixed: a hidden block (`template`, `svg`, ...) reset the line cursor to column 0 on close, so the next visible text
  drew over the previous line; a newline after a hidden element no longer adds an extra blank row.
- Tests: smoke section 19c (select + textarea submission); sections 1, 15-19c pass; flex/box screenshots unchanged.

## 2026-10-15 (v1.7 -- HTML5 element coverage)
- Every HTML5 element gets a sensible UA default: ~20 more block elements, void/self-closing elements no longer leak a
  style-stack entry, hidden-by-default elements (`template svg math iframe object embed map datalist noembed`),
  `sub/sup/del/s/cite/dfn/var/samp/th` styling, `td/th` separated by a space. `<br>` unchanged. README updated.
  Smoke sections 1, 15-19 pass; checked by screenshot.

## 2026-10-15 (v1.6 -- forms, POST, entities, scroll keys, window move)
- **Forms**: `<form>` + `<input>` (text/search/email/...; password masked; hidden; checkbox; radio groups; submit/
  button/reset-as-button) and `<button>`. Click a field to focus it, type (SDL text input), Backspace, Enter submits,
  Esc/Tab unfocus. Submission is `application/x-www-form-urlencoded`: **GET** appends `?name=value&...` to the action
  (or the current URL), **POST** sends the same bytes as the body with `Content-Length` (a redirect after a POST is
  followed as GET). 24 controls per page, 32 bytes per text value, 1000 bytes encoded per submit (bigger is refused,
  logged, not truncated). Values/names decode `&amp;` etc. before encoding. Not built: `<textarea>`, `<select>`,
  `file`, `required`/validation, `enctype` multipart, `<label for>`, `disabled`.
- **HTML entities** (`&amp; &lt; &gt; &quot; &apos; &nbsp; &#NN; &#xHH; &lsquo; &rsquo; &ldquo; &rdquo; &ndash;
  &mdash; &hellip; &copy; &reg; &trade; &bull; &middot; &laquo; &raquo; &times; &rarr; &larr;`) and the UTF-8 forms
  of curly quotes, dashes, ellipsis, nbsp decode to their ASCII look-alikes (the embedded font is ASCII only); other
  non-ASCII characters show `?` instead of one garbage cell per byte. Links' `href` decode `&amp;` too.
- **Keys**: PageUp/PageDown (a screen minus a row), Home, End (now the real last screen, not +20 rows), scroll is
  clamped to the page. **Shift+J/L/I/K** move the borderless window left/right/up/down by 48 px
  (`sdl2-raw-move-window`, PARENA `575bdf5`).
- **Body/html styling**: `body`/`html` rules and `style=` (background, color, margin, padding, border, width) were
  verified; the canvas now takes `<html>`'s background when set, else `<body>`'s.
- Smoke section 19 (GET, POST body reaching the server, entities, scroll keys, window move). Verified live under
  Xvfb with screenshots. Not run: the Bazel build, the HTTPS form path (same code behind `stream-connect-tls`).
## 2026-10-15 (v1.5 -- <img>, PNG)
- `<img src>`: PNG (8-bit RGB/RGBA/palette, non-interlaced) fetched after the page stream closes, decoded by PARENA's
  `image/png`, held in the new `image/store` pixel pool, drawn scaled (nearest neighbour). Placeholder text while
  loading/failing; layout shifts when pixels land. Needs PARENA `7a03498` (second stream bank, `stream-copy-bytes`,
  image store) -- pin bumped. Smoke section 18. CSS background images deliberately not supported.
- Verified over plain HTTP in Xvfb with screenshots (RGBA with transparent corner, RGB scaled by `width=`, palette,
  404, JPEG, a 512x512 random-noise 1 MB PNG, a 3000x3000 PNG refused). Bazel suite and the HTTPS image path not run here.

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
