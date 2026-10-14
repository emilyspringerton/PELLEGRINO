/* pellegrino_host.c -- the whole C harness. main() and nothing else: everything real lives in
 * pellegrino.prn (compiled to pellegrino_gen.inc by `parena build`).
 *
 * NO MALLOC: built with -DPARENA_NO_MALLOC, so the PARENA runtime serves every arena block from a
 * static pool (no heap call anywhere in the runtime or this file; SDL itself is the one thing that
 * allocates, inside its own library).
 *
 * stdout/stderr go to real text files next to the executable, so a GUI-subsystem Windows build
 * (no console window) still leaves a log instead of a terminal that flashes and closes. */
#include "pellegrino_gen.inc"
#include <stdio.h>

#ifndef PELLEGRINO_VERSION
#define PELLEGRINO_VERSION "dev"
#endif

int main(int argc, char **argv) {
    if (!freopen("pellegrino.out.log", "a", stdout)) return 90;
    if (!freopen("pellegrino.err.log", "a", stderr)) return 91;
    fprintf(stderr, "pellegrino %s\n", PELLEGRINO_VERSION);
    return pellegrino_run(argc > 1 ? argv[1] : "");
}
