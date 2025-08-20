import SwiftUI

struct TiledBackground: View {
    var base: Color = Color(hex: "#6E8F8C")
    var tileSize: CGFloat = 32
    var cornerRadius: CGFloat = 18

    // tuning knobs
    var lightTileProbability: Double = 0.25
    var lightAlphaTiles: Double = 0.08
    var gridAlpha: Double = 0.08
    var seed: UInt64 = 17

    var body: some View {
        GeometryReader { geo in
            let cols = Int(ceil(geo.size.width  / tileSize))
            let rows = Int(ceil(geo.size.height / tileSize))

            ZStack {
                // 👉 Solid base only
                base

                // 👉 Light tiles + light grid
                Canvas { ctx, size in
                    let lightColor = Color.white.opacity(lightAlphaTiles)

                    // Sparse random light tiles
                    for r in 0..<rows {
                        for c in 0..<cols {
                            if random01(r: r, c: c, seed: seed) < lightTileProbability {
                                let rect = CGRect(
                                    x: CGFloat(c) * tileSize,
                                    y: CGFloat(r) * tileSize,
                                    width: tileSize,
                                    height: tileSize
                                )
                                ctx.fill(Path(rect), with: .color(lightColor))
                            }
                        }
                    }

                    // Grid lines — same light tone
                    let gridColor = Color.white.opacity(gridAlpha)
                    let style = StrokeStyle(lineWidth: 0.5)

                    for c in 0...cols {
                        let x = CGFloat(c) * tileSize
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(p, with: .color(gridColor), style: style)
                    }
                    for r in 0...rows {
                        let y = CGFloat(r) * tileSize
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: .color(gridColor), style: style)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    // deterministic random
    private func random01(r: Int, c: Int, seed: UInt64) -> Double {
        var v = UInt64(bitPattern: Int64(r &* 73856093) ^ Int64(c &* 19349663)) ^ seed
        v ^= v &>> 33; v &*= 0xff51afd7ed558ccd
        v ^= v &>> 33; v &*= 0xc4ceb9fe1a85ec53
        v ^= v &>> 33
        return Double(v & 0xFFFFFFFFFFFF) / Double(0x1000000000000)
    }
}


// Hex helper unchanged
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >>  8) & 0xFF) / 255.0
            a = Double( value        & 0xFF) / 255.0
        default:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >>  8) & 0xFF) / 255.0
            b = Double( value        & 0xFF) / 255.0
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
