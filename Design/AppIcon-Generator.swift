import AppKit
import CoreGraphics

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(dark: Bool, to path: String) {
    let size = 1024
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let S = CGFloat(size)
    // Koordinaten: Ursprung oben links
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

    // Hintergrund
    let bg = dark ? [rgb(0x23205A), rgb(0x0E0C26)] : [rgb(0x8380FF), rgb(0x4A43E4)]
    let grad = CGGradient(colorsSpace: cs, colors: bg as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: S, y: S), options: [])
    // weiches Licht oben links
    let glow = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF, dark ? 0.08 : 0.22), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 300, y: 220), startRadius: 0, endCenter: CGPoint(x: 300, y: 220), endRadius: 620, options: [])

    // Pfad-Stationen (unten links → oben rechts)
    let a = CGPoint(x: 372, y: 792), b = CGPoint(x: 664, y: 574), c = CGPoint(x: 452, y: 318)
    let pathColor = dark ? rgb(0x8C88FF, 0.5) : rgb(0xFFFFFF, 0.42)
    ctx.setLineCap(.round); ctx.setLineWidth(62); ctx.setStrokeColor(pathColor)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 560, y: 1090))
    ctx.addCurve(to: a, control1: CGPoint(x: 470, y: 960), control2: CGPoint(x: 330, y: 900))
    ctx.addCurve(to: b, control1: CGPoint(x: 420, y: 650), control2: CGPoint(x: 640, y: 700))
    ctx.addCurve(to: c, control1: CGPoint(x: 690, y: 440), control2: CGPoint(x: 520, y: 420))
    ctx.strokePath()

    func node(_ p: CGPoint, r: CGFloat, fill: CGColor, edge: CGColor) {
        // "gedrückte" Kante unten wie die Knoten in der App
        ctx.setFillColor(edge)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r + r * 0.16, width: 2 * r, height: 2 * r))
        ctx.setFillColor(fill)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    }
    let nodeFill = dark ? rgb(0x6E6AF5) : rgb(0xFFFFFF)
    let nodeEdge = dark ? rgb(0x3F3AB8) : rgb(0xC9C7FF)
    let checkColor = dark ? rgb(0xFFFFFF) : rgb(0x5B57F0)
    for p in [a, b] {
        node(p, r: 92, fill: nodeFill, edge: nodeEdge)
        ctx.setStrokeColor(checkColor); ctx.setLineWidth(30); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: p.x - 38, y: p.y + 2))
        ctx.addLine(to: CGPoint(x: p.x - 10, y: p.y + 30))
        ctx.addLine(to: CGPoint(x: p.x + 40, y: p.y - 26))
        ctx.strokePath()
    }
    // Ziel: goldener Knoten mit Stern
    node(c, r: 132, fill: rgb(0xFFC41F), edge: rgb(0xD9930A))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.beginPath()
    for i in 0..<10 {
        let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let radius: CGFloat = i % 2 == 0 ? 80 : 34
        let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + 4 + sin(angle) * radius)
        if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
    }
    ctx.closePath(); ctx.fillPath()

    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
render(dark: false, to: CommandLine.arguments[1])
render(dark: true, to: CommandLine.arguments[2])
