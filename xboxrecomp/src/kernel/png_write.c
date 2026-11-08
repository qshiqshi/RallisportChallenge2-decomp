/*
 * png_write.c -- a frame as a PNG, for screenshots.
 *
 * macOS has a PNG encoder in ImageIO, so it is used there; elsewhere this
 * returns 0 and the caller writes a BMP instead (no codec is vendored).
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__)
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>

/* rgb: w*h pixels, 3 bytes each, top row first. 1 when the file is written. */
int xbox_WritePngRGB(const char *path, const uint8_t *rgb, uint32_t w, uint32_t h)
{
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, rgb, (size_t)w * h * 3, NULL);
    CGImageRef img = NULL;
    CFURLRef url = NULL;
    CGImageDestinationRef dst = NULL;
    int ok = 0;

    if (cs && dp)
        img = CGImageCreate(w, h, 8, 24, (size_t)w * 3, cs, kCGBitmapByteOrderDefault | kCGImageAlphaNone,
                            dp, NULL, false, kCGRenderingIntentDefault);
    if (img)
        url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)path, (CFIndex)strlen(path), false);
    if (url)
        dst = CGImageDestinationCreateWithURL(url, CFSTR("public.png"), 1, NULL);
    if (dst) {
        CGImageDestinationAddImage(dst, img, NULL);
        ok = CGImageDestinationFinalize(dst) ? 1 : 0;
    }
    if (dst) CFRelease(dst);
    if (url) CFRelease(url);
    if (img) CGImageRelease(img);
    if (dp) CGDataProviderRelease(dp);
    if (cs) CGColorSpaceRelease(cs);
    return ok;
}
#else
int xbox_WritePngRGB(const char *path, const uint8_t *rgb, uint32_t w, uint32_t h)
{
    (void)path; (void)rgb; (void)w; (void)h;
    return 0;
}
#endif
