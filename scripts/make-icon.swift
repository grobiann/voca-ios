import AppKit
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
// Warm ivory, matching the travel map and calendar icons in the user's folder.
NSColor(red: 0.98, green: 0.95, blue: 0.87, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
func card(_ rect: NSRect, angle: CGFloat, color: NSColor, border: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    let transform = AffineTransform(translationByX: 512, byY: 512)
    var rotate = transform; rotate.rotate(byDegrees: angle); rotate.translate(x: -512, y: -512)
    (rotate as NSAffineTransform).concat()
    let path = NSBezierPath(roundedRect: rect, xRadius: 66, yRadius: 66)
    color.setFill(); path.fill()
    border.setStroke(); path.lineWidth = 10; path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}
card(NSRect(x: 255, y: 220, width: 490, height: 610), angle: 15,
     color: NSColor(red: 0.84, green: 0.89, blue: 0.82, alpha: 1),
     border: NSColor(red: 0.17, green: 0.36, blue: 0.28, alpha: 0.55))
card(NSRect(x: 265, y: 190, width: 490, height: 610), angle: -8,
     color: NSColor(red: 1.0, green: 0.99, blue: 0.95, alpha: 1),
     border: NSColor(red: 0.17, green: 0.36, blue: 0.28, alpha: 0.9))
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "HiraginoSans-W5", size: 300) ?? NSFont.systemFont(ofSize: 300), .foregroundColor: NSColor(red: 0.15, green: 0.36, blue: 0.28, alpha: 1)]
let text = "あ" as NSString
let bounds = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (1024-bounds.width)/2, y: 340), withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "VocaApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
