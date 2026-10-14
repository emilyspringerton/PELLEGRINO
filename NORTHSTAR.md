# PELLEGRINO — NORTHSTAR (vibes pass, 2026-10-14)

**How to read this.** The founder's framing (`docs/source/00-founder-framing.md`): the Gemini conversation "is getting the
vibes but it's totally a crack head" — keep the vibes, assume the implementation is nonsense. So this NORTHSTAR is written
from the *feel* of the conversation. Nothing here is a spec; no code, number, API name or protocol claim from Gemini is
adopted. Implementation gets designed fresh, in PARENA, when we build.

The repo's own README already says it: *all gas; no brakes; powered by PARENA. "Do not confuse momentum with permission."
With <4 from america. CLEAN BUILDS FIRST.*

## 1. The feeling

A browser that feels like a drag strip with a clean pit. You hit enter and words are already on the glass. Pages don't
"load" — they pour in, packet by packet, and you can watch the internet arrive. When you leave, the whole previous page is
just gone, instantly, like it never happened. It runs in a terminal over SSH exactly as happily as in a borderless window.
It is small enough to hand someone on a floppy disk. It belongs to nobody, so it belongs to everybody.

## 2. The vibes, distilled

| Vibe | What it means for the product |
|---|---|
| **Speed you can see** | Text appears the moment bytes arrive; no spinner, no blank-then-pop. The network's truth is shown, not hidden. |
| **Forgetting is a feature** | One page, one clean slate; navigate = wipe. No leaks to hunt, no accumulated cruft. The page lives and dies whole. |
| **Shapeshifter** | The window and the terminal are two views of the same thing. Display is a guest, never a landlord. |
| **Small, unencumbered, public** | Tiny binary, no ownership, public domain. Anyone can copy it onto anything. |
| **Fast *and* clean** | "No brakes" works *because* of "CLEAN BUILDS FIRST": PARENA's compile-time region safety is what makes it safe to drop runtime brakes — discipline up front, none at runtime. |
| **Terminal-native** | The browser is also a shell: you drive it by typing, pipe things through it, mutate what's on screen. |
| **Loud, defiant, with love** | Pirate/mixtape energy, Detroit in October, an American signature, "prove us wrong." It should have a voice. |
| **Honest and raw** | Telemetry on the glass, layout allowed to jank, unstyled-first. Beauty from being direct, not from polish. |

## 3. What we are not taking

All of Gemini's *how*: the code blocks, function and type names, timing and size budgets, the HTTP/3 and Wasm plumbing,
the legal "can't be sued" reasoning, the hand-off file, the marketing mechanics. Treat them as brainstorm exhaust. If a
number or mechanism matters, it gets rediscovered and **measured** on our own build.

## 4. The one real tension, and how the vibes resolve it

"All gas, no brakes" vs "CLEAN BUILDS FIRST" read like a contradiction. The consistent reading: **brakes are a runtime
cost; cleanliness is a pre-flight guarantee.** PELLEGRINO takes its safety from the compiler (regions, no GC, no manual
free) so the engine itself can run without guard rails. Where we genuinely can't buy safety at compile time — hostile
content, sandboxing — we say plainly that PELLEGRINO is for trusted content rather than faking it.

## 5. What it could become

1. **The feel demo** — pour a page onto a terminal at wire speed, wipe on navigate. Proves the feeling.
2. **A daily driver for text** — docs, feeds, news tickers, status boards; a live "firehose" mode that just repaints.
3. **The shapeshifter** — same engine as a window, a terminal, an SSH session; a command bar to drive it.
4. **The mixtape** — shipped in the open, loud and small, with a public head-to-head against bloat that anyone can rerun.

## 6. First move (a hypothesis, not a spec)

When we build: the smallest thing that gives the feeling — fetch a page and stream its words onto a terminal as they
arrive, wipe on navigate, with a benchmark that prints real numbers so "prove us wrong" is actually true. Decisions about
parsing, layout and display get made then, PARENA-first, against what PARENA really has. This section is deliberately thin.

## 7. Relationships

- **PARENA** — the language and the source of every dependency; gaps we hit become PARENA work first.
- **`PARENA/stdlib/gfd/browser`** — a separate, existing design (FFI to a real embeddable engine). PELLEGRINO is the
  opposite bet and sits beside it, not over it.
- **TYLER** — the documentary/aesthetic thread in the conversation belongs to that universe; parked, not a build item.
- **Terminal siblings (EmilyOS, PITVIPER, SAND, DUNG)** — reuse, don't fork, where terminal pieces already exist.

## 8. Open questions for the founder

1. **Name.** "Pellegrino" is also a real mineral-water brand; the Unlicense covers copyright, not trademark. Keep it, keep
   it quieter, or rename (PEREGRINE, CICINDELA, ODONATA, CYBISTER were the alternates)?
2. **Voice.** How much of the provocation ("F*ck your trademarks", `<4 America` in headers/banners) lives in the product
   vs. the README and art?
3. **Safety line.** Confirm the plain statement: trusted content only, no sandbox, until a real isolation story exists.
4. **Distribution.** Signed releases + CONSTRUCT like every repo, or something more mixtape-shaped?

## 9. Non-goals

A standards-compliant general-purpose browser. A JS engine. CSS parity. An extension ecosystem. Anything that adds runtime
brakes to look responsible.
