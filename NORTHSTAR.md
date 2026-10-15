# PELLEGRINO — NORTHSTAR (vibes pass, 2026-10-14)

**How to read this.** The founder's framing (`docs/source/00-founder-framing.md`): the Gemini conversation "is getting the
vibes but it's totally a crack head" — keep the vibes, assume the implementation is nonsense. So this NORTHSTAR is written
from the *feel* of the conversation. Nothing here is a spec; no code, number, API name or protocol claim from Gemini is
adopted. Implementation gets designed fresh, in PARENA, when we build.

The repo's own README already says it: *all gas; no brakes; powered by PARENA. "Do not confuse momentum with permission."
With <4 from america. CLEAN BUILDS FIRST.*

## 0. Status (2026-10-14)

v1 is built and shipping: a borderless SDL2 window that fetches a URL over HTTP or **HTTPS** (live, winsock on Windows;
TLS through the PARENA runtime's mbedTLS binding, chain and hostname always verified) and
streams it onto the glass, or an embedded/file page; pure
PARENA + a ~25-line C host, no malloc (TLS included — mbedTLS runs on a static heap), logs to real files, Bazel build,
headless smoke test, and CI that auto-tags and releases Linux + Windows bundles on every green push to `main`. The product page is `site/`.
See `README.md` for the honest built / not-built split. Everything below this section is still the direction.

## 1. The feeling

A browser that feels like a drag strip with a clean pit. You hit enter and words are already on the glass. Pages don't
"load" — they pour in, packet by packet, and you can watch the internet arrive. When you leave, the whole previous page is
just gone, instantly, like it never happened. It runs in a terminal over SSH exactly as happily as in a borderless window.
It is small enough to hand someone on a floppy disk. It belongs to nobody, so it belongs to everybody.

## 2. The vibes, distilled

| Vibe | What it means for the product |
|---|---|
| **Everything at once** | HTTP/2 and HTTP/3 multiplexing is the *protocol* expression of the whole project: one pipe, many interleaved streams, text and boxes and images all assembling on the glass simultaneously. Founder: "the HTTP2/3 stuff is good." |
| **Speed you can see** | Text appears the moment bytes arrive; no spinner, no blank-then-pop. The network's truth is shown, not hidden. |
| **Forgetting is a feature** | One page, one clean slate; navigate = wipe. No leaks to hunt, no accumulated cruft. The page lives and dies whole. |
| **Shapeshifter** | The window and the terminal are two views of the same thing. Display is a guest, never a landlord. |
| **Small, unencumbered, public** | Tiny binary, no ownership, public domain. Anyone can copy it onto anything. |
| **Fast *and* clean** | "No brakes" works *because* of "CLEAN BUILDS FIRST": PARENA's compile-time region safety is what makes it safe to drop runtime brakes — discipline up front, none at runtime. |
| **Terminal-native** | The browser is also a shell: you drive it by typing, pipe things through it, mutate what's on screen. |
| **Loud, defiant, with love** | Pirate/mixtape energy, Detroit in October, an American signature, "prove us wrong." It should have a voice. |
| **Honest and raw** | Telemetry on the glass, layout allowed to jank, unstyled-first. Beauty from being direct, not from polish. |

## 2b. The protocol vibe: one pipe, everything at once (founder-endorsed)

HTTP/1.1 is a single-lane road: ask, wait, ask again, and one stuck file blocks the rest. **HTTP/2** slices everything —
HTML, images, fonts — into tagged binary frames and interleaves them down one connection; **HTTP/3** rides QUIC over UDP
so one lost packet no longer freezes the other streams. That is exactly PELLEGRINO's temperament: every stream lands in
the same frame arena as it arrives, and the visualizer shows the page stitching itself together from many streams at
once instead of scrolling top to bottom. The founder called this part good; it is a pillar, not a footnote.

Honest status (updated 2026-10-15): PARENA now has `net/quic_client` (QUIC v1 + TLS 1.3 + HTTP/3, QPACK static) as well as
`net/tcp`, `net/udp`, `net/tls`, `net/http`, `net/dns`, `net/wire`. It still has **no HTTP/2 and no HPACK**. Per the monorepo's *Core Deps Are PARENA-First*
rule those are built in PARENA before the feature that needs them — so the protocol ladder below is real, sequenced work,
not a switch we flip.

## 3. What we are not taking

All of Gemini's *how*: the code blocks, function and type names, timing and size budgets, the specific frame-header, ring-buffer
and Wasm plumbing (the *idea* of multiplexed streams into an arena stays; the mechanism gets designed fresh),
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
4. **The firehose** — multiplexed HTTP/2 then HTTP/3 streams interleaving straight into the frame arena.
5. **The mixtape** — shipped in the open, loud and small, with a public head-to-head against bloat that anyone can rerun.

## 6. First move and the protocol ladder (hypotheses, not a spec)

**First move.** The smallest thing that gives the feeling — fetch a page and stream its words onto a terminal as they
arrive, wipe on navigate, with a benchmark that prints real numbers so "prove us wrong" is actually true. Decisions about
parsing, layout and display get made then, PARENA-first, against what PARENA really has.

**Protocol ladder** (each rung is its own PARENA stdlib piece with its own tests; each unlocks more of the "everything at
once" feeling):

1. **HTTP/1.1 over TCP** — exists today (`net/http`); enough for the feel demo.
2. **TLS** — **built** (v0.4): `net/stream`'s TLS half over mbedTLS 3.6 (TLS 1.3 + 1.2), always-verified chain + hostname,
   static-heap so the no-malloc rule holds. Needed because real HTTP/2 and HTTP/3 are TLS-only in practice. ALPN is
   the next step for HTTP/2; mbedTLS cannot do QUIC, so HTTP/3 will need its own TLS answer.
3. **HTTP/2** — frame codec, stream ids, HPACK, flow control; interleaved streams into the arena. First true
   multiplexed page load.
4. **HTTP/3 over QUIC** — **built (v1.13)**: QUIC v1 transport + TLS 1.3 in PARENA over `net/udp`-style
   binary-safe datagrams, HTTP/3 framing + QPACK; independent streams, no head-of-line blocking. Verified against
   aioquic and live servers; limits (one connection, GET only, static QPACK, no congestion control) in README.md.
   Still open: HTTP/2 (rung 3), multiplexing several streams into the arena at once, 0-RTT, a congestion controller.

The 40 ms / 60 ms targets from the founder's own prompts apply to the whole ladder: *something* on the glass fast, and the
number is measured on real runs, not asserted.

## 7. Relationships

- **PARENA** — the language and the source of every dependency; gaps we hit become PARENA work first.
- **`PARENA/stdlib/gfd/browser`** — a separate, existing design (FFI to a real embeddable engine). PELLEGRINO is the
  opposite bet and sits beside it, not over it.
- **TYLER** — the documentary/aesthetic thread in the conversation belongs to that universe; parked, not a build item.
- **Terminal siblings (EmilyOS, PITVIPER, SAND, DUNG)** — reuse, don't fork, where terminal pieces already exist.

## 8. Open questions for the founder

1. **Safety line.** Confirm the plain statement: trusted content only, no sandbox, until a real isolation story exists.
2. **Distribution.** Signed releases + CONSTRUCT like every repo (what CI does today), or something more mixtape-shaped?

## 9. Non-goals

A standards-compliant general-purpose browser (beyond what the protocol ladder implies). A JS engine *inside* the core.
(The founder's own idea for scripting: don't embed one — "shell out JS to Wasm," streaming script bytes into an isolated
worker with no DOM that dies with the frame. A vibe worth keeping for later; no mechanism adopted.) CSS parity. An extension ecosystem. Anything that adds runtime
brakes to look responsible.
