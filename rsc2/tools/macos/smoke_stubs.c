/*
 * smoke_stubs.c -- stand-ins for the code that rsc2/regen.sh generates from
 * the game's default.xbe, so the host side of the port (launcher, window,
 * game thread, Vulkan on MoltenVK, audio, input) builds and runs on a Mac
 * that has no copy of the game. Only in the -DRSC2_SMOKE=ON build; a real
 * build never links this file.
 *
 * With the synthetic XBE from xboxrecomp/tools/conformance/mkxbe.py as
 * game/default.xbe, rsc2_main boots the runtime and ends up in
 * xbe_entry_point below. RSC2_SMOKE_FRAMES=<n> then opens the game window
 * and presents n frames, each a GPU clear of a 640x480 surface in guest
 * RAM: the same clear -> flip -> present path a title's frames take.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "nv2a_vk.h"

typedef void (*recomp_func_t)(void);

extern void xbox_FramebufferWindowStart(void);
extern void xbox_FramebufferWindowSet(uint32_t fb_va, uint32_t pitch);

int recomp_dispatch_init(void) { return 1; }
recomp_func_t recomp_lookup(uint32_t va) { (void)va; return NULL; }

#define SMOKE_STUB(name) \
    void name(void) { fprintf(stderr, "[SMOKE] %s called -- no game code\n", #name); abort(); }
SMOKE_STUB(sub_00076C54_gen)
SMOKE_STUB(sub_000A8FA0_gen)
SMOKE_STUB(sub_000A98D0_gen)
SMOKE_STUB(sub_001DBF90)
SMOKE_STUB(sub_002A35E0_gen)
SMOKE_STUB(sub_002C17B0_gen)
SMOKE_STUB(sub_00325C90)

/* A colour wheel, so a frame that did not change is easy to spot. */
static uint32_t hue(int f)
{
    int h = f % 360, x = (h % 60) * 255 / 60, r, g, b;
    switch (h / 60) {
    case 0:  r = 255;     g = x;       b = 0;       break;
    case 1:  r = 255 - x; g = 255;     b = 0;       break;
    case 2:  r = 0;       g = 255;     b = x;       break;
    case 3:  r = 0;       g = 255 - x; b = 255;     break;
    case 4:  r = x;       g = 0;       b = 255;     break;
    default: r = 255;     g = 0;       b = 255 - x; break;
    }
    return 0xFF000000u | (uint32_t)r << 16 | (uint32_t)g << 8 | (uint32_t)b;
}

/* RSC2_SMOKE_MMIO=1: guest-style loads and stores to the NV2A registers the
 * interrupt model traps. Each one faults, goes through the signal handler
 * (Darwin's thread state into a CONTEXT), the AArch64 instruction decoder
 * and the register model, and resumes past the instruction -- the path every
 * device register access of the game takes on this host. */
static int smoke_mmio(void)
{
    extern ptrdiff_t xbox_GetMemoryOffset(void);
    volatile uint32_t *time0 = (volatile uint32_t *)(xbox_GetMemoryOffset() + 0xFD009400u);
    volatile uint32_t *alarm = (volatile uint32_t *)(xbox_GetMemoryOffset() + 0xFD009420u);
    volatile uint32_t *pbus  = (volatile uint32_t *)(xbox_GetMemoryOffset() + 0xFD001200u);
    volatile uint32_t *pmc_en = (volatile uint32_t *)(xbox_GetMemoryOffset() + 0xFD000140u);
    volatile uint8_t  *pmc_b = (volatile uint8_t  *)(xbox_GetMemoryOffset() + 0xFD000141u);
    uint32_t t1, t2, a, p, e;
    uint8_t b;
    int ok = 1;

    t1 = *time0;
    usleep(20000);
    t2 = *time0;
    *alarm = 0x12345678u;
    a = *alarm;
    *pbus = 0xA5A50000u;                /* a neighbour on PMC's host page (not 0x1100: the ack thread holds PBUS_INTR_0 at 0) */
    p = *pbus;
    *pmc_en = 1u;
    e = *pmc_en;
    *pmc_b = 0x7Fu;                     /* a narrow store */
    b = *pmc_b;
    fprintf(stderr, "[SMOKE] PTIMER_TIME_0 %08X -> %08X (%s)\n", t1, t2,
            t2 != t1 ? "counts" : "STUCK");
    fprintf(stderr, "[SMOKE] PTIMER_ALARM_0 wrote 12345678, read %08X\n", a);
    fprintf(stderr, "[SMOKE] PBUS neighbour wrote A5A50000, read %08X\n", p);
    fprintf(stderr, "[SMOKE] PMC_INTR_EN_0 wrote 1, read %08X; byte +1 wrote 7F, read %02X\n", e, b);
    ok = t2 != t1 && a == 0x12345678u && p == 0xA5A50000u && e == 1u && b == 0x7Fu;
    fprintf(stderr, "[SMOKE] MMIO through the fault path: %s\n", ok ? "PASS" : "FAIL");
    return ok;
}

void xbe_entry_point(void)
{
    const char *e = getenv("RSC2_SMOKE_FRAMES");
    const uint32_t va = 0x80400000u, w = 640, h = 480, pitch = 640 * 4;
    Nv2aVkState st = { 0 };
    int frames = e ? atoi(e) : 0, f;

    if (getenv("RSC2_SMOKE_MMIO"))
        smoke_mmio();
    if (frames <= 0) {
        fprintf(stderr, "[SMOKE] no game code in this build (RSC2_SMOKE_FRAMES=n draws n test frames)\n");
        return;
    }
    fprintf(stderr, "[SMOKE] Vulkan %s\n", nv2a_vk_active() ? "up" : "NOT active");
    xbox_FramebufferWindowSet(va, pitch);
    xbox_FramebufferWindowStart();

    st.color_va = va;
    st.pitch = pitch;
    st.bpp = 4;
    st.clip_w = w;
    st.clip_h = h;
    st.color_mask = 0xFFFFFFFFu;
    for (f = 0; f < frames; f++) {
        nv2a_vk_clear(&st, 0xF0, hue(f * 2), 0);
        nv2a_vk_present(va, pitch);
        nv2a_vk_present_queued();
        nv2a_vk_flush();
        usleep(16667);
    }
    fprintf(stderr, "[SMOKE] %d frames presented\n", frames);
}
