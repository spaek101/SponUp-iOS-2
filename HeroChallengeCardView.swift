import SwiftUI

struct HeroChallengeCardView: View {
    let challenge: Challenge

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(challenge.title)
                .font(.headline)
                .foregroundColor(.black)
                .lineLimit(2)

            HStack(spacing: 4) {
                if let rewardCash = challenge.rewardCash {
                    Text("$\(String(format: "%.2f", rewardCash))")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.yellow)
                }
                if let points = challenge.rewardPoints {
                    Text("+\(points) pts")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .frame(width: 140, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
        )
    }
}
