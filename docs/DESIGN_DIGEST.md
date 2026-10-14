# PELLEGRINO — design digest

A structured summary of the founding design conversation (a Gemini chat, pasted 2026-10-14 in eight chunks), organized by
system rather than by turn. Readable text: [`transcript/`](transcript/) (9 parts). Raw: [`source/`](source/). Items marked
*(proposed)* are the conversation's suggestions, not decisions. Items marked *(unverified)* contain numbers or claims nobody
measured. For what
we adopted see `../NORTHSTAR.md`.

> **Reading rule (founder, 2026-10-14; see `source/00-founder-framing.md`):** Gemini's chat carries the *vibes*; its
> implementation — code, API names, numbers, protocol and legal claims — is assumed to be nonsense and is not used
> directly. This digest records what was said, not what is true.

## 1. Premise

A web browser engine and terminal shell written in PARENA that strips defensive browser engineering (process isolation,
speculative-execution mitigations, GC, JIT) in exchange for speed: one frame arena, a flat layout array, streaming render
straight off the wire. "A 1996 Dodge Viper of software engineering" (transcript 01). The conversation starts mid-thread; the
founding prompt was not captured.

## 2. Memory model

- One monolithic frame arena per page view; navigation resets the allocation pointer to 0 — no free(), no GC (01, 04).
- Fixed 4 MB arena, "fits L3" *(unverified)*; a 64 KB ring buffer for wire inflow; max 65,536 layout nodes (06/07).
- Tab/process isolation deliberately absent; "if Tab 1 goes off the rails it can blindside Tab 2" (01).

## 3. Layout and rendering

- No DOM tree: HTML is lexed straight into a flat `Vec LayoutNode`, depth-first (01 §3).
- "Drifting cursor" layout: x += glyph width; wrap at window width; images pushed in at the cursor; shifts are accepted (02).
- Streaming ("firehose") render: draw each chunk as it arrives; no waiting for EOF; progressive/row-by-row images (02).
- Fallback-first fonts: one local bitmap font, swap in web fonts late (02).
- Visualizer overlay: per-packet colors, "loading horizon" line, jank heatmap, memory-map strip (02); later re-themed as a
  carbonated "fizz" (04) and an October "canopy" palette (08).

## 4. Network layer

- Non-blocking TCP into the arena (01–02); HTTP/2 multiplexing and HTTP/3-over-QUIC with per-stream parsing (03).
- 1-second stateless reload as a WebSocket replacement for live feeds — wipe, GET, repaint (03).
- Wire-to-glass timing ledgers: 40 ms and 60 ms budgets *(unverified)* (01–02).

## 5. Scripting

- No JavaScript in the engine; pages ship `.prn` or precompiled plugins (01).
- Later softened: QuickJS compiled to Wasm, hosted via Wasmtime from the C client, no DOM, three host functions
  (`parena_log/fetch/mutate_ui`), instance torn down on reload (03).

## 6. Presentation (the "shapeshifter")

- One layout array, two viewports: ANSI terminal (cursor-addressed `\033[r;cH`) and borderless SDL2 window (05–06).
- Boot headless, hot-swap to SDL2 when the window is ready (~2 ms fallback timeout); fall back again if the graphics context
  dies (06). SSH/headless detected via `SSH_CLIENT`/`DISPLAY`; Windows CMD via `ENABLE_VIRTUAL_TERMINAL_PROCESSING` (06).
- Native in-browser command shell: `stream <url>`, `set visualizer 1`, `wipe`, `mutate node[42].width = 800` (06).

## 7. Packaging and build

- `parena build X.prn -o X.c` + gcc `-O3`, or Bazel `parena_compile_c`. Static musl link; target "fits a
  1.44 MB floppy" — 687 KB raw / 240 KB gzip figures *(unverified)* (06).
- Checklist rules (07): no runtime allocations, ALL-CAPS names, Unlicense in every file, User-Agent signature.

## 8. Identity, license, distribution

- Names considered: CICINDELA, ODONATA, CYBISTER → PEREGRINE → **PELLEGRINO** (sparkling-water pun) (04).
- Mottos: "All Gas, No Brakes" → **CLEAN BUILDS FIRST** (04). Signature "With love, <4 America"; "Do not confuse momentum with
  permission" (already in `README.md`).
- License: The Unlicense, as PARENA uses (05). Legal framing "nothing to sue" **.
- Distribution: Lil Wayne mixtape playbook — daily leaks, curl|gunzip, floppy drops, "prove us wrong" benchmark vs Chrome,
  YouTube Shorts + 22-minute mock documentary tied to TYLER (05, 07).

## 9. Generated artifacts (not new decisions)

Two "systems specification" documents (07), a Claude hand-off brief (09), and ~10 code sketches (`peregrine.prn`,
`pellegrino.prn`, `PELLEGRINO_HOST.c`, `BUILD.bazel`, a floppy build script). They restate the same ideas; their code
are illustrative sketches only — none of it has been built or run.
