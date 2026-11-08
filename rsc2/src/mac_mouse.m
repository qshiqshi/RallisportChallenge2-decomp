/*
 * mac_mouse.m -- where the pointer is over the launcher, asked of AppKit.
 *
 * On macOS 26 and later SDL works around an AppKit bug by taking a motion
 * event's position from the global mouse state minus the window's position,
 * which can land a row or more away from the pointer (seen with two
 * displays). Button events still carry the event's own position and are
 * right. The launcher hovers by motion, so it asks the window itself, in the
 * same window points SDL reports.
 */
#import <AppKit/AppKit.h>
#include <SDL.h>
#include <SDL_syswm.h>

int rsc2_mac_mouse(SDL_Window *win, float *x, float *y)
{
    SDL_SysWMinfo wm;
    NSWindow *nw;
    NSView *cv;
    NSPoint p;

    SDL_VERSION(&wm.version);
    if (!win || !SDL_GetWindowWMInfo(win, &wm) || wm.subsystem != SDL_SYSWM_COCOA)
        return 0;
    nw = wm.info.cocoa.window;
    cv = [nw contentView];
    if (!cv)
        return 0;
    p = [cv convertPoint:[nw mouseLocationOutsideOfEventStream] fromView:nil];
    *x = (float)p.x;
    *y = (float)([cv isFlipped] ? p.y : cv.bounds.size.height - p.y);
    return 1;
}
