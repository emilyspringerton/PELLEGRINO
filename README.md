![PELLEGRINO Logo](logo.jpg)

# PELLEGRINO

all gas; no brakes; powered by PARENA
*"Do not confuse momentum with permission."*
With <4 from america

**CLEAN BUILDS FIRST**

A web browser and terminal shell stripped to essentials: no defensive layers, no garbage collection, no
`malloc`. Written in [PARENA](https://github.com/emilyspringerton/PARENA) with a slim C host. Public domain
(The Unlicense). Landing page: [`site/`](site/index.html).

## Status — v1 (honest)

**Works today**
- Borderless SDL2 window (1280x720) that streams a page onto the glass: tags stripped, drifting-cursor
  layout, embedded 5x8 bitmap font, newest bytes tinted amber, a loading-horizon line at the stream front.
- **Live HTTP**: `pellegrino http://host/path` — or press `:` in the window, type a URL, Enter. A TCP
  connection (BSD sockets / winsock2) streams the body onto the glass as bytes land; headers are parsed,
  301/302/303/307/308 redirects followed (max 5), `<title>/<script>/<style>` content skipped.
- Source = live URL, embedded page (default), or a file path: `pellegrino path/to/page.html`.
- Keys: `:` address bar, Up/Down/Home/End or mouse wheel to scroll, Esc/q to quit.
- **No malloc**: the PARENA runtime is built with `-DPARENA_NO_MALLOC` (static pool); the C host is `main()`
  and log redirection only (`pellegrino_host.c`, ~25 lines).
- **Real log files**: `pellegrino.log` (engine), `pellegrino.out.log`, `pellegrino.err.log` next to the
  executable — the Windows build is a windowed (no-console) exe, so nothing lives only in a terminal that
  flashes and closes.
- Bazel build (`bazelisk build //:pellegrino`), headless smoke test under Xvfb (`bazelisk test //...`).
- CI from day 1: every green push to `main` auto-tags a MINOR version and publishes a GitHub Release with
  a Linux bundle (binary + bundled libSDL2 + `RUN.sh`) and a flat Windows zip (`pellegrino.exe` + `SDL2.dll`
  + `RUN.bat`), plus a deterministic CONSTRUCT source snapshot.

**Not built yet** (see [NORTHSTAR.md](NORTHSTAR.md))
- **HTTPS/TLS** (a `https://` URL shows an honest "not built yet" page — most of today's web is https-only),
  HTTP/1.0 only (no chunked/keep-alive/compression), HTTP/2, HTTP/3/QUIC, links/clicking, CSS, images,
  fonts beyond the embedded bitmap font. DNS and connect are blocking (5 s connect timeout).
- The terminal (ANSI/SSH) viewport and the terminal-to-SDL2 hot-swap.
- Any measured performance numbers: the page says "minimal / 0 ms / compact" on purpose — nothing here has
  been benchmarked yet and no figure should be quoted until a harness exists.
- **Safety:** no sandbox, no process isolation. Trusted content only.

## Run

Download the latest release, unzip, and run `RUN.bat` (Windows) or `./RUN.sh` (Linux). Pass a URL as the first argument, or
`--smoke` / `--smoke-url=http://...` for a self-exiting run (used by the CI smoke test). Check `pellegrino.log` next to the executable.

## Build

```bash
bazelisk build //:pellegrino      # needs libsdl2-dev
bazelisk test //...               # headless smoke (needs xvfb)
bash scripts/package_linux.sh     # dist/pellegrino_linux_x86_64.zip
SDL2_MINGW=/path/to/SDL2/x86_64-w64-mingw32 bash scripts/package_windows.sh   # dist/pellegrino_windows.zip
```

PARENA is pinned by commit in `MODULE.bazel`; to build against a sibling checkout add
`--override_module=parena=../PARENA`.

## Layout

| Path | What |
|---|---|
| `pellegrino.prn` | the engine (PARENA) |
| `pellegrino_host.c` | slim C harness: `main()` + log redirection |
| (PARENA) `stdlib/net/stream.prn` | the cross-platform TCP streaming primitive this engine stands on |
| `tools/gen_font.py` | generates the embedded 5x8 font table |
| `site/` | landing page |
| `docs/` | founding conversation (raw + transcript), digest |
| `NORTHSTAR.md` | what this is and where it goes |
