import SwiftUI

struct SilverCheckeredFoil: View {
    // Look & feel
    var base: Color = Color(white: 0.92)      // soft silver base
    var tileSize: CGFloat = 14                // smaller checkered boxes
    var cornerRadius: CGFloat = 14

    // Accents
    var lightTileRatio: Double = 0.25         // 25% of tiles get light-silver fill
    var lightTileAlpha: Double = 0.18         // how bright those light tiles are
    var gridAlpha: Double = 0.22              // silver grid line opacity
    var seed: UInt64 = 73                     // change for a different random pattern

    var body: some View {
        ZStack {
            base

            Canvas { ctx, size in
                // compute grid from canvas size (no GeometryReader)
                let cols = Int(ceil(size.width  / tileSize))
                let rows = Int(ceil(size.height / tileSize))

                let lightTileColor = Color.white.opacity(lightTileAlpha)

                // Random light-silver squares (~25%)
                for r in 0..<rows {
                    for c in 0..<cols {
                        if random01(r: r, c: c, seed: seed) < lightTileRatio {
                            let rect = CGRect(
                                x: CGFloat(c) * tileSize,
                                y: CGFloat(r) * tileSize,
                                width: tileSize,
                                height: tileSize
                            )
                            ctx.fill(Path(rect), with: .color(lightTileColor))
                        }
                    }
                }

                // Very light silver grid lines
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
        // Optional: helps rendering perf when layered
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    // deterministic noise
    private func random01(r: Int, c: Int, seed: UInt64) -> Double {
        var v = UInt64(bitPattern: Int64(r &* 73856093) ^ Int64(c &* 19349663)) ^ seed
        v ^= v &>> 33; v &*= 0xff51afd7ed558ccd
        v ^= v &>> 33; v &*= 0xc4ceb9fe1a85ec53
        v ^= v &>> 33
        return Double(v & 0xFFFFFFFFFFFF) / Double(0x1000000000000)
    }
}
