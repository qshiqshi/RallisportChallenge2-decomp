/*
 * lift_check.c -- run the lifted C of the synthetic XBE's five functions on
 * this host and compare every result with the same function written in C.
 * On Apple silicon that is the path the game's own code takes: x86 lifted to
 * C, compiled for arm64, running against the guest stack in guest memory.
 */
#include "xbox_memory_layout.h"
#include "recomp_funcs.h"
#include <stdio.h>
#include <stdlib.h>

recomp_func_t recomp_lookup_manual(uint32_t va) { (void)va; return 0; }

static uint32_t call(void (*fn)(void), int n, const uint32_t *args)
{
    uint32_t esp0 = g_esp;
    int i;
    for (i = n - 1; i >= 0; i--) {          /* cdecl: right to left */
        g_esp -= 4;
        MEM32(g_esp) = args[i];
    }
    g_esp -= 4;
    MEM32(g_esp) = 0xDEADBEEFu;             /* the return address */
    fn();
    g_esp = esp0;                           /* the caller cleans up */
    return g_eax;
}

static uint32_t rng(void)
{
    static uint32_t s = 0x9E3779B9u;
    s ^= s << 13; s ^= s >> 17; s ^= s << 5;
    return s;
}

int main(int argc, char **argv)
{
    static const uint32_t edge[] = { 0, 1, 2, 31, 32, 0x7FFFFFFFu, 0x80000000u,
                                     0xFFFFFFFFu, 0x12345678u, 0xFFFF0000u };
    const char *path = argc > 1 ? argv[1] : "test.xbe";
    FILE *f = fopen(path, "rb");
    unsigned char *xbe;
    long n;
    int i, bad = 0, runs = 0;

    if (!f) { fprintf(stderr, "cannot read %s\n", path); return 2; }
    fseek(f, 0, SEEK_END); n = ftell(f); fseek(f, 0, SEEK_SET);
    xbe = malloc((size_t)n + (4u << 20));
    if (!xbe || fread(xbe, 1, (size_t)n, f) != (size_t)n) return 2;
    fclose(f);
    if (!xbox_MemoryLayoutInit(xbe, (size_t)n)) { fprintf(stderr, "memory layout failed\n"); return 2; }
    g_xbox_mem_offset = xbox_GetMemoryOffset();
    g_esp = 0x00F7FFF0u;

    for (i = 0; i < 2000; i++) {
        uint32_t a = i < 100 ? edge[i % 10] : rng();
        uint32_t b = i < 100 ? edge[(i / 10) % 10] : rng();
        uint32_t c = rng();
        uint32_t args[3] = { a, b, c }, got, want, m;
        struct { const char *name; void (*fn)(void); int n; uint32_t want; } t[5];
        int k;
        m = ~(a & b);
        t[0].name = "add3";   t[0].fn = sub_00011000; t[0].n = 3; t[0].want = a + b + c;
        t[1].name = "submul"; t[1].fn = sub_00011010; t[1].n = 2; t[1].want = (a - b) * 3u;
        t[2].name = "shifts"; t[2].fn = sub_00011020; t[2].n = 2; t[2].want = a << (b & 31);
        t[3].name = "cmpsel"; t[3].fn = sub_00011030; t[3].n = 2;
        t[3].want = (int32_t)a >= (int32_t)b ? b : a;
        t[4].name = "bits";   t[4].fn = sub_00011040; t[4].n = 2; t[4].want = m * m;
        for (k = 0; k < 5; k++) {
            got = call(t[k].fn, t[k].n, args);
            want = t[k].want;
            runs++;
            if (got != want && bad++ < 10)
                fprintf(stderr, "  %s(%08X, %08X, %08X) = %08X, want %08X\n",
                        t[k].name, a, b, c, got, want);
        }
    }
    printf("lifted code on this host: %d checks, %d wrong -- %s\n", runs, bad, bad ? "FAIL" : "PASS");
    xbox_MemoryLayoutShutdown();
    return bad != 0;
}
