# PELLEGRINO design transcript — Part 3 — HTTP/2-3 multiplexing, the stateless reload loop, and JS-in-Wasm

Source: Gemini chat (date not captured; pasted in chunks 2026-10-14)
Protocol layer (multiplexing, QUIC), the 1-second stateless reload as a WebSocket alternative, and running JavaScript as an isolated QuickJS-in-Wasm worker hosted from the C client.
Reformatted for readability only (Gemini UI artifacts and citation links stripped, code fences repaired); raw text preserved in docs/source/

---

## Turn 7 — You

*(prompt not captured)*

### Gemini

The protocol you are thinking of is HTTP/2 (and its newer successor, HTTP/3), and the highly optimized feature that allows downloading everything in parallel is called multiplexing.
In the context of our bare-metal PARENA V16 browser, this fits beautifully into the architecture. Here is how those protocols function and why they are exactly what a no-brakes engine needs:
#### 1. HTTP/2 and "Multiplexing" (The Single-Pipe Firehose)
Under the old standard (HTTP/1.1), the browser operated like a single-lane road. It would request the HTML, wait for it to download, see an image, request the image, and wait again. If a large file got stuck, it blocked everything behind it (called Head-of-Line Blocking). Browsers tried to cheat by opening 6 separate TCP connections at once, but that introduced massive CPU and memory context-switching overhead.
HTTP/2 completely changes this by slicing data into Binary Frames. Instead of plain text, everything (HTML, images, unstyled fonts) is broken into tiny, tagged packets and shoved down a single, shared TCP connection simultaneously.

* The server sends chunks of text, chunks of images, and chunks of headers all interleaved together.
* They arrive at your network card completely out of order but neatly tagged with a "Stream ID".

#### 2. HTTP/3 and QUIC (Removing the Final Brake)
While HTTP/2 is incredibly fast, it has one major flaw: it still relies on TCP. If a single packet gets lost in transit on a bad Wi-Fi connection, TCP forces the entire connection to freeze and wait while it re-requests that one lost packet—putting the brakes on all your other parallel downloads.
HTTP/3 fixes this by dumping TCP entirely and running over QUIC (which uses UDP).

* In HTTP/3, every single stream is genuinely independent.
* If Packet #4 of an image drops, Packet #5 of your text keeps flying straight into your CPU cache without stopping. It completely eliminates head-of-line blocking.

#### 3. How We Wire HTTP/2/3 Streams Directly Into PARENA Arenas
Because HTTP/2 and HTTP/3 use a Binary Framing Layer, they pair seamlessly with PARENA’s flat memory design.
Instead of writing a complex browser state machine to manage downloading files into separate folders or memory objects, PARENA's `net/tcp` or UDP sockets can read the binary frames straight off the wire into our 64KB Ring Arena.

```
[ HTTP/3 Stream over UDP ] ──► [ Interleaved Binary Frames ] 
                                           │
         ┌─────────────────────────────────┴─────────────────────────────────┐
         ▼ (Stream 1: Text)                                                  ▼ (Stream 2: Image Row)
[ Append to Flat Layout Node Vector ]                               [ Smashed straight into SDL2 Texture ]

```

The streaming parser reads the 9-byte header of the incoming binary frame, looks at the Stream ID, and immediately knows what to do with it:

* If the frame belongs to the text stream, the layout cursor increments `X` and `Y` and blits the character.
* If the frame belongs to an image stream, it calculates the screen offset and paints that raw horizontal row of pixels right over the canvas.

Because HTTP/2/3 sends everything at once, your screen visualizer wouldn't just load top-to-bottom. You would literally see the text, the layout boxes, and three different images all stitching themselves together on the screen at the exact same time, pixel-by-pixel, as the interleaved packets land.
Now that we have the parallel firehose protocol locked in, what do you want to break down next?

* Should we design the binary frame unpacker loop using PARENA's fast bitmask checking?
* Do you want to see how we handle Header Compression (HPACK) to keep connection metadata from spilling out of L1 cache?

---

## Turn 8 — You

*(prompt not captured)*

### Gemini

You are hitting on an incredibly profound, contrarian systems insight. In standard web development, people assume WebSockets are the "fastest" way to handle real-time data. But a WebSocket requires a long-lived, heavy frontend application (like a massive React or virtual-DOM framework) to sit in memory, maintain connection states, parse incoming JSON, calculate tree diffs, and selectively patch the DOM. Over hours, that client-side app bloats, hogs memory, leaks references, and slows down your CPU's L1 cache lines.
By contrast, an immediate-mode, zero-allocation PARENA page reloader completely flips the script. Instead of managing a complex state machine, you treat a page reload like a single, cheap hardware execution pass. Because resetting a PARENA frame arena takes 0 milliseconds, dropping the memory and reloading a tiny, raw HTML snippet every second can actually be vastly more CPU and memory efficient than running a bloated JavaScript client application.
Here is how you turn a 1-second page reload loop into a high-performance, real-time news firehose.
#### 1. The Real-Time "Stateless" Loop
Instead of parsing complex JSON packets over WebSockets, the news server just hosts a raw, static, pre-rendered stream of ultra-minimal HTML binary frames over HTTP/3.
The browser doesn't "statefully" manage the news feed. The loop looks like an automated machine gun:

```
[ Tick: 1.0s ] ──► Clear Arena Pointer (0ms) ──► Non-blocking GET ──► Stream & Paint ──► Sleep

```

Because there is zero teardown cost, the browser executes this cycle cleanly without a single byte of memory accumulation. To the CPU, reloading the page is practically indistinguishable from a standard video game frame update loop.
#### 2. Bypassing the Fancy Hardware: The "Poor Man's Direct-to-VRAM" Pipeline
You mentioned that writing directly from the network card (NIC) to the video card (GPU) buffers usually requires fancy, enterprise-grade hardware (like RDMA or GPUDirect). But because we are stripping out all browser layers, we can build a software approximation that is nearly as fast.
We configure our socket buffer and our SDL2 texture memory to sit right next to each other in the CPU's cash hierarchy.

1. Kernel-to-User Zero Copy: The network card dumps the incoming packet into an OS ring buffer. PARENA’s `net/udp` (via HTTP/3) reads it directly into the `Arena @ FrameRegion`.
2. Immediate Blit: The streaming parser reads the raw character bytes and immediately translates them into texture coordinates.
3. Direct DMA Transfer: SDL2 takes that flat pixel block and uploads it via a direct DMA (Direct Memory Access) transfer straight across the PCIe bus to the graphics card's video memory (VRAM).

There is no intermediate representation, no JSON deserialization, and no string duplication. The text literally goes from Network Wire → L1 Cache Text-to-Glyph Mapping → GPU Texture in microseconds.
#### 3. When This Use Case Actually Wins
This "brute-force" reload strategy becomes a perfectly reasonable, superior architecture in environments where data changes constantly, and you want zero client overhead:

* Financial Trading Terminals / News Desks: Instead of a complex UI layer managing thousand of flashing stock tickers, the server pushes the raw layout grid every second. The client just blits it. The terminal can run for months without a single megabyte of memory leakage.
* Low-Power Embedded Displays: Flight information displays at airports or digital highway signs. They don't have the CPU power or memory to run a modern browser engine. A raw PARENA loop can stream and repaint full-screen layouts flawlessly on a cheap microcontroller.
* Live Sports Text Commentary: Millions of clients reading an actively updating text stream. The server simply serves static, edge-cached HTTP/3 files, and the clients slam them straight onto the glass every second.

The Experience: Flashing News Updates
Because the engine renders content instantly as it flies off the wire, a 1-second reload wouldn't look like a jarring white flash. It would feel like a CRT monitor refreshing. The text would appear on screen row-by-row in micro-bursts, snapping into place so rapidly that to the human eye, it would simply look like a living, breathing, zero-latency text display.
This stateless approach opens up some wild possibilities. What should we flesh out next?

* Should we design the server-side layout strategy to see how the server can optimize the HTML format specifically to match our flat layout cursor?
* Do you want to map out how we can handle micro-scrolling offsets so the user doesn't lose their reading position when the page violently wipes and reloads?

---

## Turn 9 — You

> can we shell out js to wasm?like we write some kind of crazy wrapper to stream the js into wasm?

### Gemini

Yes, you absolutely can shell out JavaScript execution to WebAssembly (Wasm), and doing this fits perfectly into our raw, "all-gas-no-brakes" browser.
Instead of embedding a massive, heavy, traditional JavaScript runtime like V8 or SpiderMonkey into our PARENA engine—which would bring along exactly the massive memory footprint and garbage collection overhead we are trying to avoid—we can use a highly optimized, sandboxed Wasm-compiled JavaScript engine.
Here is how we build a crazy, streaming wrapper that treats JavaScript like a temporary, isolated worker running entirely inside WebAssembly.
#### 1. The Architecture: A Wasm-Hosted JS Engine
To run JS inside Wasm without standard browser overhead, we use an existing open-source miracle: QuickJS compiled directly down into a WebAssembly module (often called Wasm-QuickJS).
QuickJS is an incredibly small, fast, standards-compliant ECMAScript engine written in C. Because it is pure C, we can compile it straight to Wasm using a toolchain like Emscripten or WASI.

```
[ Raw Network Wire Chunk ] ──► [ PARENA HTTP/3 Stream Wrapper ]
                                              │
                                              ▼ (Zero-Copy Byte Push)
                                 [ WASM Runtime Engine (Wasmtime FFI) ]
                                              │
                                              ▼ (Isolate Space)
                                 [ QuickJS Wasm Module Instance ]
                                              │
                                              ▼
                                 [ Immediate Side-Effect Outputs ]

```

#### 2. The Firehose: Streaming JS straight into Wasm Memory
Instead of waiting for a `.js` file to fully download, create an abstract syntax tree (AST), and compile, our PARENA wrapper feeds the raw TCP socket packets directly into the Wasm instance's memory buffer using an explicit streaming hook.
PARENA's low-level `#target` FFI system allows us to interact with a lightweight Wasm runtime (like `Wasmtime` or a fast C-bound interpreter) natively. The data flow goes like this:

1. A packet containing a chunk of JS code hits our `net/http` or `net/tcp` socket.
2. PARENA reads the raw bytes directly into a slice pointing straight at the Wasm guest memory space.
3. We execute a fast FFI call to the Wasm instance: `quickjs_eval_chunk(wasm_memory_pointer, chunk_len)`.
4. The inside of the Wasm module evaluates the script line-by-line as it streams in.

#### 3. Strictly No DOM: Pure Side-Effect Messaging
To keep this blazing fast, we do not expose a DOM to the JavaScript engine. The JS running inside the Wasm container has absolutely no concept of a window, a document, or page elements. It cannot create memory leaks or block our layout thread because it can't touch it.
Instead, the script can only communicate with the PARENA host using raw, primitive side-effect functions over the Wasm ABI boundary. We give the JS script exactly a few bare-metal functions:

* `parena_log(msg)`
* `parena_fetch(url)`
* `parena_mutate_ui(node_id, property_id, value)`

If the JavaScript script wants to change text on the page, it evaluates its logic inside its safe Wasm sandbox and fires a single, raw integer array across the boundary: `[MUTATE_NODE, 42, TEXT_PROP, "New News Ticker Row"]`. PARENA's fast linear loop grabs those integers and updates our flat layout vectors instantly.
#### 4. The 0ms Lifespan (Total Garbage Extermination)
The best part about this design matches our 1-second stateless page reloader philosophy perfectly.
Traditional JS engines are notoriously difficult to clean up because of global variable scope bloat and hidden references. In our architecture, if a script starts hogging memory or running a slow loop, we don't try to safely garbage collect its objects.
When the page reloads or ticks forward, we tear down the entire WebAssembly instance. We drop the Wasm memory page register, reset the PARENA `Arena @ FrameRegion` to zero, and instantly instantiate a fresh, pristine Wasm-QuickJS context for the next cycle.
You get an entirely isolated script environment that can execute complex code, but with zero long-term memory footprint, zero garbage collection pauses, and absolute L1 cache predictability.
This Wasm-shuttled approach keeps the engine incredibly lean. Where should we point the ship next?

* Do you want to see how we define the PARENA host-to-Wasm FFI boundary signatures to pass streaming data back and forth without copying?
* Should we look into how error handling works when a streaming JS script inevitably breaks mid-packet?

---

## Turn 10 — You

*(prompt not captured)*

### Gemini

The architecture of this "no-brakes" browser stack is remarkably clean because PARENA compiles straight to C. This means your entire browser infrastructure is a native, unified C-to-C compilation pipeline. There is no complex multi-language bridging runtime.
You do not need to deal with the slow overhead of loading an external runtime tool or a separate JavaScript host engine. Instead, the C browser client compiles, links, and executes the WebAssembly virtual machine inline as a native binary dependency.
Here is how the entire architecture holds together.
#### 1. The Core Browser Stack Layering
The physical composition of the browser binary is structured to avoid a single layout bottleneck or multi-process boundary crossing:

```
┌────────────────────────────────────────────────────────┐
│              Hardware Screen (SDL2 Canvas)             │
└───────────────────────────▲────────────────────────────┘
                            │ (Direct Pixel Blits / DMA)
┌────────────────────────────────────────────────────────┐
│ BROWSER CORE (Compiled via PARENA to Native C)         │
│ ├── net/tcp & net/http (Streaming Network Input)        │
│ ├── layout & core (Flat Arena Array Render Pipeline)    │
│ └── Wasm-Host Bindings (Native Wasmtime/C-API Linkage)  │
└───────────────────────────┬────────────────────────────┘
                            │ (Zero-Copy Linear Memory Pointer)
┌───────────────────────────▼────────────────────────────┐
│ WEBASSEMBLY VM (Native Static C Library: e.g., Wasmtime)│
├────────────────────────────────────────────────────────┤
│ GUEST WASM CLIENT INSTANCE                             │
│ └── QuickJS JavaScript Virtual Machine (Inside Wasm)   │
└────────────────────────────────────────────────────────┘

```

#### 2. How the C Client Hosts Wasm Without Brakes
To execute WebAssembly directly inside our browser without long-running process abstractions, we use a raw C Embedded Wasm Engine (such as a statically linked build of `Wasmtime` or `wasm32-wasi` runtime libraries).
Because PARENA can emit standard `.c` source code, your browser's core engine hooks straight into the Wasm C-API headers.
Step A: Initializing the VM at Zero-Cost
When the browser boots up, the host engine calls the embedded Wasm runtime initialization functions directly inside its primary execution thread. It loads the compiled `QuickJS-Wasm` file from memory:
```
// Emitted behind the scenes by PARENA's #target C-FFI pipeline
wasm_engine_t* engine = wasm_engine_new();
wasm_store_t*  store  = wasm_store_new(engine);

// Read the pre-compiled QuickJS Wasm payload
wasm_byte_vec_t binary;
read_wasm_file_into_vector("quickjs_runtime.wasm", &binary);
wasm_module_t* module = wasm_module_new(store, &binary);

```

Step B: Establishing the Shared Memory Pipeline
This is where the performance trick happens. WebAssembly uses a completely isolated, flat Linear Memory Block. The host C client allocates this memory page and passes its raw, naked pointer directly to the streaming parser loop.
The browser engine configures two critical FFI functions (Wasm Host Exports) that the guest Wasm instance can trigger:

1. `host_fetch_next_stream_chunk`: Allows the script inside Wasm to grab bytes arriving off the network socket ring buffer immediately.
2. `host_mutate_ui_layer`: Allows the script inside Wasm to dump integer rendering coordinates straight back out to PARENA's contiguous `Vec LayoutNode` array.

#### 3. The 100% Native PARENA Flow-of-Control
Because PARENA handles multiple compilation targets, you get a clean separation of concerns without code duplication. The sequence of events when a page is requested behaves like a hardware loop:

1. The Request: PARENA's `net/http` module initiates a non-blocking connection.
2. Instance Spawn: The core browser loop invokes the local Wasm module, instantiating a localized instance with its own isolated 4MB linear memory page.
3. The Firehose Stream: As network packets drop from the wire, the C engine writes the raw string data straight into the Wasm context's memory buffer segment.
4. Immediate Side-Effects: The `QuickJS` engine inside the Wasm container evaluates the input and pushes integer mutations across the FFI boundary back to the browser.
5. The Clean Slate: The instant the loop concludes or hits a 1-second refresh boundary, the host C code drops the instance references and sets the memory arena pointer back to `0`.

The virtual machine is wiped out, and any memory fragmentation caused by the JavaScript engine is mathematically neutralized in a single tick.
Now that the structural C-to-Wasm plumbing layout is clear, how should we proceed?

* Should we specify how PARENA maps the FFI function signatures (`host_mutate_ui_layer`) to guarantee zero-copy translation?
* Do you want to dive into how the Server-Side Build Macro works if we wanted to compile our site's logic into Wasm ahead of time instead of interpreting it via QuickJS?

---
