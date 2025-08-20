import SwiftUI

struct SuggestedChallengesSection: View {
    @Binding var challenges: [Challenge]
    @Binding var selectedFilter: SuggestedFilter
    let headerType: String
    let onClaim: (Challenge) -> Void

    // Optional onShowMore closure to show the "Show More" button only if this is set
    let onShowMore: (() -> Void)?

    // Optional custom builder for ChallengeCardView (returning AnyView to erase type)
    var challengeCardViewBuilder: ((Challenge, @escaping (Challenge) -> Void) -> AnyView)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(sectionTitle)
                    .font(.title3.bold())
                    .foregroundColor(.black)
                Spacer()
                if shouldShowMoreButton {
                    Button {
                        onShowMore?()
                    } label: {
                        Label("Show More", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.blue))
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 16) {
                // ✅ Use stable identity so cells don't get reused for different items
                ForEach(filteredChallenges, id: \.id) { ch in
                    if let builder = challengeCardViewBuilder {
                        // Also tag the view with a stable id (defensive)
                        builder(ch, onClaim)
                            .id(ch.id ?? UUID().uuidString)
                    } else {
                        ChallengeCardView(
                            challenge: ch,
                            onClaim: onClaim
                        )
                        // Tag with stable id to prevent state reuse
                        .id(ch.id ?? UUID().uuidString)
                    }
                }
            }
        }
    }

    private var filteredChallenges: [Challenge] {
        let filtered = challenges.filter { ch in
            switch headerType {
            case "sponsored": return ch.type == .sponsored
            case "rewards":   return ch.type == .reward
            case "training":  return ch.type == .training
            case "event":     return ch.type == .eventFocus
            default:          return false
            }
        }
        switch headerType {
        case "sponsored": return Array(filtered.prefix(4))
        case "rewards":   return Array(filtered.prefix(8))
        case "training":  return Array(filtered.prefix(8))
        case "event":     return Array(filtered.prefix(4))
        default:          return []
        }
    }

    private var sectionTitle: String {
        switch headerType {
        case "sponsored": return "Sponsored Challenges"
        case "rewards":   return "Game Challenges"
        case "training":  return "Training Challenges"
        case "event":     return "Event Focus Challenges"
        default:          return "Challenges"
        }
    }

    private var shouldShowMoreButton: Bool {
        if headerType == "sponsored" {
            // Show if one or more sponsored challenges exist in full challenge list
            return challenges.contains(where: { $0.type == .sponsored })
        }
        // For other types, show only if onShowMore closure is provided
        return onShowMore != nil
    }
}
