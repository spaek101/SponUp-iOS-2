import SwiftUI

struct ChallengeRowView: View {
    let challenge: Challenge
    let isSponsored: Bool
    let useBlackText: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(challenge.title)
                    .font(.headline)
                    .foregroundColor(useBlackText ? .black : .white)
                Text(challenge.type.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            if isSponsored {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(useBlackText ? Color.white : Color.black)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}


