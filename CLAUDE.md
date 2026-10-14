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
