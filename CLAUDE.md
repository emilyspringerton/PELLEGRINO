# CLAUDE.md — PELLEGRINO

Read the monorepo root `CLAUDE.md` (The Emily Way) first; this file is repo-specific.

- **Pure PARENA first.** The engine lives in `pellegrino.prn`. The C host (`pellegrino_host.c`) stays as slim as
  possible: `main()` + log redirection. Missing core deps get built in PARENA (`PARENA/stdlib/...`) first.
- **NO MALLOC.** Built with `-DPARENA_NO_MALLOC` (static pool). Do not add heap calls to the host or PARENA code.
- **Bazel is the build.** `bazelisk build //:pellegrino`, `bazelisk test //...`. PARENA is pinned by commit in
  `MODULE.bazel`; bump it deliberately after pushing PARENA changes. Local dev: `user.bazelrc` (gitignored) can
  carry `--override_module=parena=...` and SDL include/lib paths.
- **Logs go to files**, never only to a terminal (the Windows build has no console). Use `pg-log` in the engine.
- **CI/CD from day 1**: `.github/workflows/ci.yml` auto-tags and releases on every green push to `main`.
  Windows client = flat zip of `pellegrino.exe` + `SDL2.dll` + `RUN.bat`. Do not break that layout.
- **CONSTRUCT** (`scripts/generate_construct.sh`) is auto-generated; do not hand-edit or gitignore it.
- Gemini's implementation in `docs/transcript/` is vibes, not source — do not copy its code or numbers.
  No performance number goes in any doc until a benchmark harness produced it.
- VS0 quirks learned: `let` only as a function/let/match/if-condition body (not inside `do`); no variadic `+`;
  `when` is unreliable as an expression (use `if ... 0`); pass arenas as `&mut a`; lowercase `f64/i32` types are
  invalid (`F64`/`I32`); multi-file builds need `string array io sdl2` in that order.
- **TLS verification is never optional.** There is deliberately no flag/env/API to disable certificate or hostname
  checks; do not add one (not "for testing" either — tests mint their own CA and point `SSL_CERT_FILE` at it, see
  `tests/smoke.sh`). Do not hand-roll crypto: TLS is mbedTLS via PARENA's `net/stream`.
- **mbedTLS is pinned** in two places that must agree (`MODULE.bazel` and `third_party/mbedtls/mbedtls.env`;
  `//:check_pins` enforces it). Its config is `third_party/mbedtls/pellegrino_user_config.h` (static-heap allocator).
- **Releases ship `cacert.pem`** (Windows has no system trust store). Keep it in both zips.
- **Style engine** (v1.2) lives in `pellegrino.prn` between `style engine` and `navigation`: cursor (col/row), rule
  table and style stack are all *slots* (see the slot map in that block's header; PARENA runtime has 1024 cells).
  VS0 quirks found there: a `let` inside a `cond` arm of a non-loop function is rejected (use a helper fn);
  two sequential `loop`s in one function must not reuse a variable name (C redefinition); `(+ a b c)` is rejected
  (nest it). Toggle keys: F12/`x` css, F11/`p` markdown (SDLK_F11/F12 are the literal 1073741892/3).
- Box model (v1.3): style-stack field 20 = content width px (-1 auto); margin-left/right `auto` is stored as the
  sentinel 100000 and resolved in `finish-geom` (children now wrap at the parent's slot-23 edge, so parent padding/border
  is respected). No `height` (the 24-field stack stride is full).
- Flexbox (v1.4): scratch slots 610-620 (see the header block in `pellegrino.prn`), single level; children share the
  start row (`flex-enter`), `fill-start` stops later columns repainting the container chain over earlier ones. VS0: `do`
  inside an `if` in a `let` binding does not compile (`do(...)` emitted) -- wrap it in a helper fn.
- Images (v1.5): img entries live in slots 700+4k (see header); fetch is `img-pump` (frame loop), only when the page
  stream is closed, via PARENA's stream bank 1; `stream-buf` is a C string -- never read image bytes through it, use
  `stream-copy-bytes`. Cap w*h at 262144: decode memory is ~5x the pixel bytes out of the static pool.
- Forms (v1.6): control entries at slots 1100+14k (header comment above `fm-base`); global form slots 1086-1098.
  `PARENA_SLOTS` is 2048 now. A POST is "encoded body in the line buffer + slot 1095"; `start-nav` clears the flag
  after dispatch so redirects go back to GET. `string/char-at` is a *signed* char -- use `byte-at` for UTF-8.
  Window move needs `sdl2-raw-move-window` (PARENA 575bdf5+).
- HTML5 gaps (v1.8): style-stack field 21 on an HTML entry = 20 underline / 21 line-through (counted in slots 631/632;
  `pop-entry` releases). Hidden-element bookkeeping: slots 635-637 (see `hide-end`); `close-block` must not touch the
  cursor when `hid`. Details toggles: slots 660+2k, depth table 680+d; table columns 650-657; `<select>` is form entry
  kind 7 (+2 = chosen index; its submitted value is re-read from the page); `<textarea>` is kind 1 seeded at first
  sight (only once `</textarea>` has arrived). **VS0 trap hit twice:** `(if (< gt 0) A B)` with the arms the wrong way
  round compiles fine -- check the polarity of every `-1`-means-missing guard.
- CSS3 (v1.9): the rule table is slots 2100+6k sorted by specificity (k < 160; selectors are matched at apply time, right
  to left, by `sel-match`); the ancestor table (`xget`) is 1500+10d; sheets are 3100+10k (k < 16, count 1640, fetch
  state 1641-1643); custom properties 1740 (count) / 1750+4k; viewport 1646/1647; calc 1632-1634. A slot-map overlap
  (sheet entries over the custom-property table) once crashed with "arena block alloc failed" -- when adding a table,
  check the whole 0-4095 map. External CSS text lives in PARENA's static css store (`css-buf`); selectors and
  declarations are (source, start, end) ranges into the page or that store. Never fetch a sheet over TLS while the
  page's own TLS session is open (one session): https sheets wait for slot 4 < 0.
- UA defaults (v1.10): `ua-v` sets a block's default margin rows; `margin-rows` collapses against the run of margin-only
  blank rows just emitted (slot 1656 = run length, 1657 = the row it ended on). Slots 1655 = hash of `li` (nested list
  test), 1658 = hash of `pre`, 1660 = HTML-document flag (whitespace collapsing, `soft-ws?`), 1661 = last logged rows.
  Do not put a blank row back into `pre-break`: author resets depend on margins being the only source of gaps.
