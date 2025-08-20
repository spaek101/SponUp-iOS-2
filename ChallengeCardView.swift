import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let onClaim: (Challenge) -> Void
    var fundButton: Bool = false            // sponsor context
    var isFunded: Bool = false              // already funded in backend
    var isSelected: Bool = false            // currently selected in sponsor's cart

    private var defaultCashFromDifficulty: Int {
        switch challenge.difficulty {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 20
        }
    }

    private var isSponsoredOrFunded: Bool {
        (challenge.type == .sponsored) || isFunded || fundButton
    }

    private var cashDisplay: Int {
        if let rc = challenge.rewardCash, rc > 0 { return Int(rc) }
        return defaultCashFromDifficulty
    }

    private var buttonTitle: String {
        if fundButton {
            if isFunded { return "Funded" }       // locked (already funded in backend)
            if isSelected { return "Remove" }     // in cart
            return "Fund"                         // not in cart
        } else {
            return isFunded ? "Remove" : "Accept"
        }
    }

    private var buttonBackground: Color {
        if fundButton {
            if isFunded { return .gray }
            return isSelected ? Color(red: 0.93, green: 0.87, blue: 0.74) : .brown
        } else {
            return isFunded
                ? Color(red: 0.93, green: 0.87, blue: 0.74)
                : .brown
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            if let uiImage = UIImage(named: challenge.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(12, corners: [.topLeft, .topRight])
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                .frame(height: 120)
                .cornerRadius(12, corners: [.topLeft, .topRight])
            }

            // Title
            Text(challenge.title)
                .font(.headline)
                .lineLimit(1)
                .padding(.horizontal, 8)

            // Reward line
            let pts = challenge.rewardPoints ?? 0
            if isSponsoredOrFunded {
                Text("$\(cashDisplay) +\(pts) pts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else {
                Text("\(pts) pts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }

            Spacer(minLength: 8)

            // Action button
            Button(action: {
                // If already funded in backend, do nothing (locked)
                guard !(fundButton && isFunded) else { return }
                onClaim(challenge)  // toggles cart selection
            }) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonBackground)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding([.horizontal, .bottom], 8)
            .disabled(fundButton && isFunded)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 12.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
