// Turns a partner logo into a one-colour PNG: ink colour, transparent background, trimmed to the mark.
// Build: swiftc -O tools/logo-mono.swift -o tools/logo-mono
// Usage: tools/logo-mono in.(png|jpg|svg) out.png mode [height=160]
//   mode "dark":  ink follows how dark each pixel is (white areas and knockouts stay empty) - for colour logos
//   mode "solid": every opaque pixel becomes ink - for white-on-transparent logos
import AppKit

let a = CommandLine.arguments
let src = NSImage(contentsOfFile: a[1])!
let mode = a[3], outH = a.count > 4 ? Int(a[4])! : 160
let ink: (r: Double, g: Double, b: Double) = (0x23 / 255.0, 0x08 / 255.0, 0x1C / 255.0) // --ink

// Rasterise at a generous size so vectors and small PNGs both come out clean.
let scale = max(1.0, 1600 / max(src.size.width, src.size.height))
let W = Int(src.size.width * scale), H = Int(src.size.height * scale)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: W * 4, bitsPerPixel: 32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
src.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.restoreGraphicsState()

let p = rep.bitmapData!
var mask = [Double](repeating: 0, count: W * H)
var minX = W, minY = H, maxX = 0, maxY = 0
func smooth(_ e0: Double, _ e1: Double, _ x: Double) -> Double { let t = min(1, max(0, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t) }
for y in 0..<H { for x in 0..<W {
  let i = (y * W + x) * 4
  let al = Double(p[i + 3]) / 255
  var m = al
  if mode == "dark" && al > 0 {
    // un-premultiply, then darkness; any clearly non-white colour becomes (nearly) full ink
    let r = Double(p[i]) / 255 / al, g = Double(p[i + 1]) / 255 / al, b = Double(p[i + 2]) / 255 / al
    let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    m = al * smooth(0.03, 0.2, 1 - lum)
  }
  mask[y * W + x] = m
  if m > 0.03 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
}}

// Trim to the mark and scale to the output height.
let cw = maxX - minX + 1, chh = maxY - minY + 1
let oh = outH, ow = Int((Double(cw) / Double(chh) * Double(oh)).rounded())
let full = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cw, pixelsHigh: chh, bitsPerSample: 8, samplesPerPixel: 4,
                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: cw * 4, bitsPerPixel: 32)!
let q = full.bitmapData!
for y in 0..<chh { for x in 0..<cw {
  let m = mask[(y + minY) * W + (x + minX)], o = (y * cw + x) * 4
  q[o] = UInt8(ink.r * m * 255); q[o + 1] = UInt8(ink.g * m * 255); q[o + 2] = UInt8(ink.b * m * 255); q[o + 3] = UInt8(m * 255) // premultiplied
}}
let outImg = NSImage(size: NSSize(width: ow, height: oh))
outImg.addRepresentation(full)
let dst = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: ow, pixelsHigh: oh, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: ow * 4, bitsPerPixel: 32)!
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: dst)!
ctx.imageInterpolation = .high
NSGraphicsContext.current = ctx
outImg.draw(in: NSRect(x: 0, y: 0, width: ow, height: oh))
NSGraphicsContext.restoreGraphicsState()
try! dst.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
print(a[2], ow, "x", oh)
