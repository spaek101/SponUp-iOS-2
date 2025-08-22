import SwiftUI

struct SuggestedChallengesSection: View {
    @Binding var challenges: [Challenge]
    @Binding var selectedFilter: SuggestedFilter
    let headerType: String
    let onClaim: (Challenge) -> Void

    // Optional “Show More” handler (only used for non-sponsored sections)
    let onShowMore: (() -> Void)?

    // Optional custom builder for the card
    var challengeCardViewBuilder: ((Challenge, @escaping (Challenge) -> Void) -> AnyView)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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

            // Empty state (Sponsored only)
            if headerType == "sponsored" && filteredChallenges.isEmpty {
                HStack {
                    Spacer()
                    Text("No sponsored challenges to display")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                // Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredChallenges, id: \.id) { ch in
                        if let builder = challengeCardViewBuilder {
                            builder(ch, onClaim)
                                .id(ch.id ?? UUID().uuidString)
                        } else {
                            ChallengeCardView(challenge: ch, onClaim: onClaim)
                                .id(ch.id ?? UUID().uuidString)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Derived

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
        case "sponsored": return filtered            // no limit
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
        // Show for non-sponsored sections only when handler exists
        guard onShowMore != nil else { return false }
        switch headerType {
        case "rewards", "training", "event": return true
        case "sponsored": return false
        default: return false
        }
    }
}
