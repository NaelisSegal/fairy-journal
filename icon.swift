// Draws the app icon: a white ❀ on a soft pink tile.
import Cocoa
let out = CommandLine.arguments[1]
for px in [16, 32, 64, 128, 256, 512, 1024] {
    let s = CGFloat(px)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let inset = s * 0.1
    let r = NSRect(x: inset, y: inset,
                   width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: r, xRadius: r.width * 0.22,
                            yRadius: r.width * 0.22)
    NSColor(red: 1, green: 0.62, blue: 0.78, alpha: 1).setFill()
    path.fill()
    let font = NSFont.systemFont(ofSize: s * 0.55, weight: .bold)
    let str = NSAttributedString(string: "❀", attributes: [
        .font: font, .foregroundColor: NSColor.white])
    let sz = str.size()
    str.draw(at: NSPoint(x: (s - sz.width) / 2,
                         y: (s - sz.height) / 2))
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath:
        "\(out)/px_\(px).png"))
}
