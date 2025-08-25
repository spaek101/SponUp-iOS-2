import SwiftUI
import UIKit

struct ViewLeaderboard: View {
    // change this to your actual asset name
    private let assetName = "leaderboard_hero_7x5"

    var body: some View {
        ZStack {
            if let uiImg = UIImage(named: "ViewLeaderboard") {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()  // Fills the 7:5 card
                    .accessibilityHidden(true)
            }else {
                // Fallback if asset isn't found
                LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.orange)
                            Text("Leaderboard")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    )
            }

            // Foreground CTA
            VStack {
                Spacer()
                Text("VIEW LEADERBOARD")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.blue.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 14)
        }
        // The parent sets .frame(width: cardW, height: cardH)
        .clipped()
        .contentShape(Rectangle())
    }
}
