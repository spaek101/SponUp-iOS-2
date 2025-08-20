import SwiftUI

struct WelcomeHeader: View {
    enum Kind {
        case athlete(points: Int, cash: Int)
        case sponsor(balance: Double, compact: Bool = false, onTopUp: (() -> Void)? = nil)
    }

    let userFirstName: String
    let userLastName: String
    let kind: Kind

    // MARK: - Initializers

    // Athlete initializer (unchanged usage)
    init(userFirstName: String, userLastName: String, points: Int, cash: Int) {
        self.userFirstName = userFirstName
        self.userLastName  = userLastName
        self.kind = .athlete(points: points, cash: cash)
    }

    // Sponsor initializer (balance in header; compact controls padding)
    init(userFirstName: String, userLastName: String, balance: Double, compact: Bool = false, onTopUp: (() -> Void)? = nil) {
        self.userFirstName = userFirstName
        self.userLastName  = userLastName
        self.kind = .sponsor(balance: balance, compact: compact, onTopUp: onTopUp)
    }

    var body: some View {
        // compact only applies to sponsor mode
        let isCompactSponsor: Bool = {
            if case .sponsor(_, let compact, _) = kind { return compact }
            return false
        }()

        HStack(spacing: 12) {
            // Left: profile + first name
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.6))
                    Text(userFirstName)
                        .foregroundColor(.black)
                        .font(.callout)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .buttonStyle(.plain)

            // Right side varies by kind
            switch kind {
            case let .athlete(points, cash):
                Spacer() // push chips to the right edge
                HStack(spacing: 8) {
                    StatChip(icon: "star.fill",              text: "\(points) pts", width: 78)
                    StatChip(icon: "dollarsign.circle.fill", text: "\(cash)",      width: 78)
                }

            case let .sponsor(balance, _, onTopUp):
                Spacer() // push wallet card to the right edge

                // Wallet amount + "+" button inside the header
                HStack(spacing: 12) {
                    Text(String(format: "$%.2f", balance))
                        .font(isCompactSponsor ? .title3.bold() : .title2.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Button("+") {
                        onTopUp?()
                    }
                    .font(.subheadline.bold())
                    .frame(width: 32, height: 32)        // square frame for circle
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(minWidth: 200, alignment: .trailing) // enough room; stays on the right
                // no maxWidth .infinity and no high layoutPriority -> prevents name from disappearing
            }
        }
        // Compact sponsor trims padding so it fits cleanly in a tight row
        .padding(.horizontal, isCompactSponsor ? 0 : 16)
        .padding(.top, isCompactSponsor ? 0 : 20)
    }
}

// Same pill style
private struct StatChip: View {
    let icon: String
    let text: String
    var width: CGFloat = 80

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .frame(width: width, height: 32)
        .background(Color.blue)
        .clipShape(Capsule())
    }
}
