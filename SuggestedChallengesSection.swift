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
                        if let onShowMore = onShowMore {
                            onShowMore()
                        } else {
                            // No action or fallback if needed
                        }
                    } label: {
                        Label("Show More", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredChallenges) { ch in
                    if let builder = challengeCardViewBuilder {
                        builder(ch, onClaim)
                    } else {
                        ChallengeCardView(challenge: ch, onClaim: onClaim)
                    }
                }
            }
        }
    }

    private var filteredChallenges: [Challenge] {
        let filtered = challenges.filter { ch in
            switch headerType {
            case "sponsored": return ch.type == .sponsored
            case "rewards": return ch.type == .reward
            case "training": return ch.type == .training
            case "event": return ch.type == .eventFocus
            default: return false
            }
        }
        switch headerType {
        case "sponsored": return Array(filtered.prefix(4))
        case "rewards": return Array(filtered.prefix(8))
        case "training": return Array(filtered.prefix(8))
        case "event": return Array(filtered.prefix(4))
        default: return []
        }
    }

    private var sectionTitle: String {
        switch headerType {
        case "sponsored": return "Sponsored Challenges"
        case "rewards": return "Game Challenges"
        case "training": return "Training Challenges"
        case "event": return "Event Focus Challenges"
        default: return "Challenges"
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
