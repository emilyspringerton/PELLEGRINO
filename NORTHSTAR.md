# PELLEGRINO — NORTHSTAR (scoping pass, 2026-10-14)

Founder pitch, from the repo's own README and the founding conversation (`docs/transcript/`, digest in
`docs/DESIGN_DIGEST.md`): *all gas; no brakes; powered by PARENA. "Do not confuse momentum with permission." With <4 from
america. CLEAN BUILDS FIRST.* A web browser engine and terminal shell written in PARENA that trades decades of defensive
browser machinery for one frame arena, a flat layout array, and rendering straight off the wire.

## 1. What PELLEGRINO is

One engine, two viewports. Bytes come off a socket into a frame arena, are tokenized into a flat array of layout nodes, and
are drawn by whichever presentation target is available: an ANSI terminal (local console or SSH) or a borderless SDL2
window. Navigation resets the arena. There is no DOM tree, no GC, no JIT, and no per-tab process.

Principles carried straight from the conversation:

1. **CLEAN BUILDS FIRST** — no feature lands on an unclean build; no GC, no lazy resource management.
2. **Arena per frame** — a page view owns one region; navigating resets it in O(1).
3. **Flat layout array, drifting cursor** — layout is a linear pass over contiguous nodes, no pointer chasing.
4. **Stream, don't wait** — paint chunks as they arrive; fallback font first; layout shifts are accepted.
5. **Presentation is a non-load-bearing dependency** — terminal and SDL2 read the same layout array.
6. **Stateless repaint mode** — a 1-second wipe-and-reload loop for live text feeds.

## 2. What exists today (checked, not assumed)

- `PELLEGRINO/` holds only `README.md`, `LICENSE` (The Unlicense), `logo.jpg` and the ingested conversation. **No engine
  code yet.**
- In PARENA already: `stdlib/net/{tcp,udp,tls,http,dns,wire,secure_channel}`, built-in `sdl2`, `vec`, `string`, `buffer`,
  region/arena primitives, `parena build X.prn -o X.c`, the `parena_compile_c` Bazel macro, `stdlib/editor/render.prn`.
- Not in PARENA: HTML tokenizer, layout engine, CSS, HTTP/2, HTTP/3/QUIC, a Wasm host, a JS engine. These are real
  dependencies and, per the monorepo's *Core Deps Are PARENA-First* rule, they get built in PARENA before the feature.
- `PARENA/stdlib/gfd/browser.prn` is a separate, existing design: an FFI binding to a real embeddable engine (CEF/
  Ultralight). PELLEGRINO is the opposite bet and does not replace it; see §6.
- Everything in the conversation is design intent. Its code blocks are sketches that have not been built or run, and its
  timing and size numbers (40 ms, 60 ms, 4 MB-in-L1, 240 KB, "2 ms boot") are targets to *measure*, not facts.

## 3. VS0 — the cut

**VS0 = a streaming text renderer.** One page, one terminal, measured.

`pellegrino <http-url>` fetches a page over plain HTTP, tokenizes a small HTML subset (text, `h1`–`h3`, `p`, `br`, `a`
shown as text + target) into a flat `Vec LayoutNode` inside one frame arena, runs the drifting-cursor layout, and draws it
to an ANSI terminal. Navigation (`stream <url>`, `wipe`) resets the arena. A fixture-driven headless test proves it.

**Definition of done**

- [ ] Tokenizer + flat layout + ANSI emitter written in PARENA (`PARENA/stdlib/pellegrino/*.prn`), compiling via `parena`.
- [ ] `pellegrino` binary built from PARENA output + a thin C host; `make test` runs against recorded HTML fixtures with
      byte-exact expected terminal output.
- [ ] Arena reset verified (a test navigates twice and asserts the second page sees a zeroed arena).
- [ ] A benchmark harness prints *measured* wire-to-first-glyph and full-layout times on the fixtures. Real numbers replace
      the conversation's targets in the README.
- [ ] README states the safety stance (§5) and honest status.

## 4. Phases after VS0

| Phase | Adds | Gate |
|---|---|---|
| P1 | SDL2 viewport over the *same* layout array (bitmap font); terminal↔SDL2 selection | both viewports render the same fixture identically |
| P2 | Streaming/progressive paint from a live socket; visualizer overlay (packet colors, loading horizon, memory strip) | demo against a slow local server |
| P3 | In-browser command shell (`stream`, `set`, `wipe`, `mutate`) | scripted shell session test |
| P4 | 1-second stateless repaint mode with scroll-offset preservation | live-feed fixture |
| P5 | TLS (reuse `net/tls`), then HTTP/2 | real https page |
| P6 | Terminal mouse tracking over SSH; ANSI color mapping | click-through fixture |
| P7 | Images (baseline decode), web fonts (late swap) | image fixture |
| P8 | Size budget: static musl build, measured against the floppy target (LZ4 for any wire/IPC format per monorepo default) | CI size check |
| Far | HTTP/3/QUIC; Wasm-hosted script worker; any CSS beyond a tiny subset | each needs its own NORTHSTAR |

## 5. Stances to state plainly

- **Safety.** No process isolation and no sandbox is a deliberate trade. PELLEGRINO is for trusted content. The README
  says so; it is not a browser for the open web until/unless an isolation story exists.
- **Distribution.** Signed GitHub Releases with a CONSTRUCT snapshot (monorepo Principle 21), like every other repo. The
  conversation's "leak unsigned daily binaries / `curl | gunzip`" tactics are **not** adopted.
- **Scripting.** No JavaScript in VS0–P8. A PARENA-native mod surface (the monorepo's existing "mods first" convention) is
  the later answer, not an embedded JS engine.

## 6. Relationship to the rest of the monorepo

- **PARENA** — the compiler and every core dep. Gaps found while building (HTML/CSS stdlib, layout, QUIC) become PARENA
  work first.
- **`gfd/browser`** — complementary. If PELLEGRINO matures, it is the native-PARENA alternative to the CEF binding for
  embedding a document view; not a replacement.
- **EmilyOS / PITVIPER / SAND / DUNG** — terminal-side siblings; PELLEGRINO's ANSI viewport and command shell overlap their
  space and should reuse, not fork, any PARENA terminal pieces that exist.
- **TYLER** — the conversation's mock-documentary/Shorts campaign ties to TYLER. Parked; not a build item.
- **IDUNA / Apples** — PELLEGRINO files its own Apples and kanban cards like any repo; no auth in VS0.

## 7. Open decisions for the founder

1. **The name.** "Pellegrino" is also a registered brand of mineral water. The Unlicense covers copyright; it does not
   cover trademarks. Keep the name and drop the "prove us wrong" provocation, keep it as-is, or rename? (Conversation
   candidates: PEREGRINE, CICINDELA, ODONATA, CYBISTER.)
2. **The `<4 America` / provocation strings** in User-Agent headers and boot banners — keep, or keep to README/art only?
3. **Terminal-first or SDL2-first** for P1 ordering (VS0 assumes terminal-first because it is testable headlessly).
4. **gfd/browser overlap** — confirm PELLEGRINO stays a separate engine rather than an alternative backend for that module.
5. **Hand-off file** — Gemini's generated `PELLEGRINO_HANDOFF.md` lists files that don't exist; not adopted.

## 8. Non-goals

A general-purpose standards-compliant browser. CSS layout parity. A JS engine. Extension ecosystem. Sandboxing. Shipping
marketing campaigns as part of the build.
