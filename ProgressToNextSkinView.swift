import SwiftUI

struct ProgressToNextSkinView: View {
    let current: Int
    let target: Int

    private var clampedProgress: CGFloat {
        guard target > 0 else { return 0 }
        return min(max(CGFloat(current) / CGFloat(target), 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress to Next Skin")
                    .font(.headline)
                Spacer()
                Text("\(Int(clampedProgress * 100))%")
                    .font(.subheadline).bold()
            }
            .foregroundColor(.white)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: w * clampedProgress)
                        .animation(.easeInOut(duration: 0.3), value: clampedProgress)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack {
                Text("\(current) points")
                Spacer()
                Text("Goal: \(target) points")
            }
            .font(.footnote)
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress to next skin \(Int(clampedProgress * 100)) percent, \(current) of \(target) points")
    }
}
