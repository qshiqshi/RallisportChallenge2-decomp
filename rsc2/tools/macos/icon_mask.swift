// icon_mask.swift <artwork.png> <out.png> -- square artwork into a macOS app
// icon: Apple's grid (an 824 pt rounded square on a 1024 canvas), a soft
// shadow and a hairline edge. The artwork is scaled to cover the tile.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3,
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let art = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("usage: icon_mask <artwork.png> <out.png>\n".data(using: .utf8)!)
    exit(1)
}
let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
              color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.35])!)
ctx.addPath(shape)
ctx.setFillColor(CGColor(colorSpace: cs, components: [0.05, 0.07, 0.12, 1])!)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
let side = max(tile.width / CGFloat(art.width), tile.height / CGFloat(art.height))
let w = CGFloat(art.width) * side, h = CGFloat(art.height) * side
ctx.interpolationQuality = .high
ctx.draw(art, in: CGRect(x: tile.midX - w / 2, y: tile.midY - h / 2, width: w, height: h))
ctx.restoreGState()

ctx.addPath(shape)
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.12])!)
ctx.setLineWidth(3)
ctx.strokePath()

let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL,
                                          UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dst)
