/* embed_test.c -- PELLEGRINO embed API under test: render an HTML+CSS page into an offscreen surface
 * renderer, simulate a click on a link, read back the activated href range, and dump the frame as PPM.
 * Build: see scripts/embed_test.sh. Exit 0 = every check passed. */
#include "pellegrino_gen.inc"
#include <stdio.h>
#include <string.h>

static int fails = 0;
#define CHECK(c, msg) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", msg); fails++; } else printf("ok: %s\n", msg); } while (0)

static int lit_pixels(const unsigned *px, int n, unsigned bg) {
    int c = 0;
    for (int i = 0; i < n; i++) if (px[i] != bg) c++;
    return c;
}

int main(int argc, char **argv) {
    const char *out = argc > 1 ? argv[1] : "embed_frame.ppm";
    char page[] =
        "<html><head><style>body{background:#101820;color:#e0e0e0}"
        "h1{color:#ffd23f}a{color:#3fa7ff}</style></head><body>"
        "<h1>SHANKPIT</h1><a href=\"shankpit:go/0\">SURVIVAL</a><br>"
        "<a href=\"shankpit:go/1\">STORY</a><br><a href=\"shankpit:back\">BACK</a></body></html>";
    int n = (int)strlen(page);
    const int W = 640, H = 360;
    if (sdl2_init_impl() < 0) { fprintf(stderr, "sdl init\n"); return 2; }
    int ren = embed_open(W, H);
    CHECK(ren >= 0, "embed_open returns a surface renderer");
    unsigned *px = (unsigned *)sdl2_surface_renderer_pixels_impl(ren);
    CHECK(px != NULL, "surface pixels reachable");
    embed_draw(ren, page, n, W, H, 1);
    int lit = lit_pixels(px, W * H, px[W * H - 1]);
    CHECK(lit > 500, "frame has painted pixels");
    CHECK(embed_action_start() == -1, "no action before any click");
    /* find the STORY link by clicking down the left column until an action lands */
    int got = -1, gy = -1;
    for (int y = 12; y < 200 && got < 0; y += 6) {
        embed_click(20, y);
        embed_draw(ren, page, n, W, H, 1);
        if (embed_action_start() >= 0) { got = embed_action_start(); gy = y; }
    }
    CHECK(got >= 0, "a click on a link reports an href range");
    if (got >= 0) {
        int e = embed_action_end();
        char buf[64]; int len = e - got; if (len > 63) len = 63;
        memcpy(buf, page + got, (size_t)len); buf[len] = 0;
        printf("clicked y=%d href=%s\n", gy, buf);
        CHECK(strncmp(buf, "shankpit:", 9) == 0, "href is the shankpit: scheme, not navigated");
        embed_ack();
        CHECK(embed_action_start() == -1, "ack clears the action");
    }
    /* keyboard: Tab selects the first link, Enter activates it */
    embed_key(9); embed_draw(ren, page, n, W, H, 1);
    embed_key(13); embed_draw(ren, page, n, W, H, 1);
    CHECK(embed_action_start() >= 0, "Tab+Enter activates a link");
    embed_ack();
    embed_draw(ren, page, n, W, H, 1);
    FILE *f = fopen(out, "wb");
    if (f) {
        fprintf(f, "P6\n%d %d\n255\n", W, H);
        for (int i = 0; i < W * H; i++) { unsigned p = px[i]; fputc((p >> 16) & 255, f); fputc((p >> 8) & 255, f); fputc(p & 255, f); }
        fclose(f);
    }
    printf("%s (%d failures)\n", fails ? "FAILED" : "PASSED", fails);
    return fails ? 1 : 0;
}
