import AppKit
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
// Keep the card mark prominent on a clean white background.
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
func card(_ rect: NSRect, angle: CGFloat, color: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: 512, byY: 512)
    var rotate = transform; rotate.rotate(byDegrees: angle); rotate.translate(x: -512, y: -512)
    (rotate as NSAffineTransform).concat()
    color.setFill(); NSBezierPath(roundedRect: rect, xRadius: 66, yRadius: 66).fill()
    NSGraphicsContext.restoreGraphicsState()
}
card(NSRect(x: 255, y: 220, width: 490, height: 610), angle: 15, color: NSColor.white.withAlphaComponent(0.30))
card(NSRect(x: 265, y: 190, width: 490, height: 610), angle: -8, color: NSColor(red: 0.97, green: 0.97, blue: 0.91, alpha: 1))
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "HiraginoSans-W5", size: 300) ?? NSFont.systemFont(ofSize: 300), .foregroundColor: NSColor(red: 0.15, green: 0.36, blue: 0.28, alpha: 1)]
let text = "あ" as NSString
let bounds = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (1024-bounds.width)/2, y: 340), withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "VocaApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
