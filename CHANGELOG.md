# Changelog

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
