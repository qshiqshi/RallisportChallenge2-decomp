// make_icon.swift <out.png> -- the app icon, drawn here (no game artwork):
// a gravel stage curving into a dusk sky over pines, a rally car on it in
// the launcher's orange. 1024x1024 on Apple's icon grid (824 pt squircle).
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)                       // top-left origin from here on

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((h >> 16) & 255) / 255, CGFloat((h >> 8) & 255) / 255,
                                         CGFloat(h & 255) / 255, a])!
}
func grad(_ c: [CGColor], _ l: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: c as CFArray, locations: l)!
}

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

// soft shadow under the tile
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(shape); ctx.setFillColor(rgb(0x0E131E)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()

let horizon: CGFloat = 548
// sky: night blue down to an orange dusk at the horizon
ctx.drawLinearGradient(grad([rgb(0x0B1220), rgb(0x1B2640), rgb(0x7C3A1C), rgb(0xFF8A2A)], [0, 0.42, 0.82, 1]),
                       start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: horizon), options: [])
// sun and its glow
let sun = CGPoint(x: 650, y: horizon - 18)
ctx.drawRadialGradient(grad([rgb(0xFFC777, 0.9), rgb(0xFF7A1A, 0)], [0, 1]), startCenter: sun, startRadius: 0,
                       endCenter: sun, endRadius: 300, options: [])
ctx.setFillColor(rgb(0xFFE6B8))
ctx.fillEllipse(in: CGRect(x: sun.x - 64, y: sun.y - 64, width: 128, height: 128))

// pines along the horizon
var seed: UInt32 = 20040406
func rnd() -> CGFloat { seed = seed &* 1103515245 &+ 12345; return CGFloat((seed >> 16) & 0x7FFF) / 32767 }
func pine(_ x: CGFloat, _ base: CGFloat, _ h: CGFloat, _ c: CGColor) {
    let w = h * 0.38
    ctx.setFillColor(c)
    for tier in 0..<3 {
        let t = CGFloat(tier)
        let top = base - h + t * h * 0.22, bot = base - h * 0.18 * (2 - t)
        let ww = w * (0.55 + 0.25 * t)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: top))
        ctx.addLine(to: CGPoint(x: x + ww / 2, y: bot))
        ctx.addLine(to: CGPoint(x: x - ww / 2, y: bot))
        ctx.closePath(); ctx.fillPath()
    }
    ctx.fill(CGRect(x: x - w * 0.05, y: base - h * 0.2, width: w * 0.1, height: h * 0.2 + 2))
}
var x: CGFloat = 70
while x < 980 { pine(x, horizon + 4, 70 + rnd() * 120, rgb(0x0D1420)); x += 26 + rnd() * 34 }

// ground
ctx.drawLinearGradient(grad([rgb(0x241D18), rgb(0x120F0D)], [0, 1]), start: CGPoint(x: 512, y: horizon),
                       end: CGPoint(x: 512, y: 924), options: [])
x = 40
while x < 1000 { pine(x, horizon + 30 + rnd() * 10, 150 + rnd() * 160, rgb(0x080B11)); x += 70 + rnd() * 90
    if x > 360 && x < 700 { x = 700 } }

// the stage: an S-curve from the bottom to the vanishing point
func bez(_ t: CGFloat, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u*u*u*a.x + 3*u*u*t*b.x + 3*u*t*t*c.x + t*t*t*d.x,
                   y: u*u*u*a.y + 3*u*u*t*b.y + 3*u*t*t*c.y + t*t*t*d.y)
}
let P0 = CGPoint(x: 560, y: 960), P1 = CGPoint(x: 820, y: 790), P2 = CGPoint(x: 300, y: 650), P3 = CGPoint(x: 492, y: horizon + 2)
func width(_ t: CGFloat) -> CGFloat { 300 * pow(1 - t, 1.5) + 5 }
// the centre line falls steadily toward the horizon, so offsetting it
// sideways (as perspective widens a road) gives a band that never folds
func band(_ from: CGFloat, _ to: CGFloat) -> CGPath {
    let p = CGMutablePath(); var l: [CGPoint] = [], r: [CGPoint] = []
    for i in 0...160 {
        let t = CGFloat(i) / 160, c = bez(t, P0, P1, P2, P3), w = width(t)
        l.append(CGPoint(x: c.x + w * from, y: c.y))
        r.append(CGPoint(x: c.x + w * to, y: c.y))
    }
    p.addLines(between: l + r.reversed()); p.closeSubpath(); return p
}
ctx.saveGState(); ctx.addPath(band(-1, 1)); ctx.clip()
ctx.drawLinearGradient(grad([rgb(0xE8C394), rgb(0xBF9163), rgb(0x7E5A3B)], [0, 0.3, 1]),
                       start: CGPoint(x: 512, y: horizon), end: CGPoint(x: 512, y: 960), options: [])
ctx.restoreGState()
// tyre tracks: two darker lines in the gravel, and the verges
for (a, b) in [(-0.62, -0.46), (0.46, 0.62)] as [(CGFloat, CGFloat)] {
    ctx.addPath(band(a, b)); ctx.setFillColor(rgb(0x5E412A, 0.5)); ctx.fillPath()
}
for (a, b) in [(-1.0, -0.93), (0.93, 1.0)] as [(CGFloat, CGFloat)] {
    ctx.addPath(band(a, b)); ctx.setFillColor(rgb(0x3A2A1E, 0.6)); ctx.fillPath()
}

// the car, seen from behind, a third of the way up the stage
let tc: CGFloat = 0.27
let cp = bez(tc, P0, P1, P2, P3), cw = width(tc) * 0.78
func rr(_ r: CGRect, _ rad: CGFloat, _ c: CGColor) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setFillColor(c); ctx.fillPath()
}
// dust thrown up behind and to the outside of the bend
for i in 0..<9 {
    let k = CGFloat(i), r = cw * (0.16 + 0.045 * k)
    let d = CGPoint(x: cp.x + cw * 0.25 + k * cw * 0.07, y: cp.y - cw * 0.02 - k * cw * 0.045)
    ctx.setFillColor(rgb(0xEBD6BA, 0.16 - 0.012 * k))
    ctx.fillEllipse(in: CGRect(x: d.x - r, y: d.y - r * 0.55, width: r * 2, height: r * 1.1))
}
let bw = cw, bh = cw * 0.40
let body = CGRect(x: cp.x - bw / 2, y: cp.y - bh, width: bw, height: bh)
// shadow, tyres
ctx.setFillColor(rgb(0x000000, 0.35))
ctx.fillEllipse(in: CGRect(x: body.minX - bw * 0.04, y: body.maxY - bh * 0.12, width: bw * 1.08, height: bh * 0.34))
rr(CGRect(x: body.minX + bw * 0.03, y: body.maxY - bh * 0.2, width: bw * 0.2, height: bh * 0.32), bh * 0.08, rgb(0x0A0C10))
rr(CGRect(x: body.maxX - bw * 0.23, y: body.maxY - bh * 0.2, width: bw * 0.2, height: bh * 0.32), bh * 0.08, rgb(0x0A0C10))
// body, cabin, rear window, wing
rr(body, bh * 0.24, rgb(0xFF7A1A))
rr(CGRect(x: body.minX + bw * 0.15, y: body.minY - bh * 0.66, width: bw * 0.70, height: bh * 0.82), bh * 0.26, rgb(0xE5650F))
rr(CGRect(x: body.minX + bw * 0.22, y: body.minY - bh * 0.52, width: bw * 0.56, height: bh * 0.44), bh * 0.12, rgb(0x16202E))
rr(CGRect(x: body.minX + bw * 0.10, y: body.minY - bh * 0.80, width: bw * 0.80, height: bh * 0.12), bh * 0.05, rgb(0x1B1F27))
// tail lights, bumper stripe
rr(CGRect(x: body.minX + bw * 0.06, y: body.minY + bh * 0.20, width: bw * 0.17, height: bh * 0.17), bh * 0.05, rgb(0xFF3030))
rr(CGRect(x: body.maxX - bw * 0.23, y: body.minY + bh * 0.20, width: bw * 0.17, height: bh * 0.17), bh * 0.05, rgb(0xFF3030))
rr(CGRect(x: body.minX + bw * 0.10, y: body.minY + bh * 0.56, width: bw * 0.80, height: bh * 0.07), bh * 0.03, rgb(0xFFFFFF, 0.8))

// a vignette for depth
ctx.drawRadialGradient(grad([rgb(0x000000, 0), rgb(0x000000, 0.35)], [0.55, 1]), startCenter: CGPoint(x: 512, y: 520),
                       startRadius: 0, endCenter: CGPoint(x: 512, y: 520), endRadius: 640, options: [])
ctx.restoreGState()
// a hairline edge
ctx.addPath(shape); ctx.setStrokeColor(rgb(0xFFFFFF, 0.10)); ctx.setLineWidth(3); ctx.strokePath()

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, img, nil)
CGImageDestinationFinalize(dst)
