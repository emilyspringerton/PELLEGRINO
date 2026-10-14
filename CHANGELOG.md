# Changelog

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
- PARENA: `stream-connect-tls` & friends @aa05cc9 (`make test-net-stream`, `make test-net-stream-tls`).

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
