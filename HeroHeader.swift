import SwiftUI

struct HeroHeader: View {
    let eventsForToday: [Event]
    let acceptedChallenges: [Challenge]
    let userFirstName: String
    let userLastName: String
    @Binding var heroHeight: CGFloat
    
    var body: some View {
        GeometryReader { proxy in
            let todays = eventsForToday.sorted { $0.startAt < $1.startAt }
            let w      = proxy.size.width
            let cardW  = max(230, w * 0.70)
            let cardH  = max(160, heroHeight * 0.82)   // card height used everywhere below
            let spacing: CGFloat = 14
            
            // 👇 Limit the container to exactly the card height (plus tiny breathing room)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    // If no events were passed in, show the NoEvents card first
                    if todays.isEmpty {
                        NavigationLink {
                            EventsView()
                        } label: {
                            NoEvents()
                                .frame(width: cardW, height: cardH)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(todays) { event in
                        heroCard(for: event, cardHeight: cardH)
                            .frame(width: cardW, height: cardH)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                    }

                    // Always append leaderboard promo
                    NavigationLink {
                        LeaderboardView()
                    } label: {
                        ViewLeaderboard()
                            .frame(width: cardW, height: cardH)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }

                .padding(.horizontal, 16)
                .padding(.vertical, 6) // keep this small to avoid extra gap
            }
            .frame(height: cardH + 12)

            .ifAvailableiOS17 { view in
                view.scrollTargetLayout()
                    .scrollTargetBehavior(.viewAligned)
            }
        }
        // ⛔️ No .frame(height:) out here – that’s what created the gap
    }
    
    
    @ViewBuilder
    private func heroCard(for event: Event, cardHeight: CGFloat) -> some View {
        let challengesForEvent = acceptedChallenges.filter { $0.eventID == event.id }
        
        ZStack {
            // Main hero background card
            TiledBackground()
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(spacing: 10) {
                // 🔹 Title + Date (inside main hero card)
                HStack(alignment: .top) {
                    // Left side: Event title
                    Text(event.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right side: Calendar block
                    VStack(spacing: 2) {
                        Text(event.startAt, format: .dateTime.weekday(.abbreviated)) // Tue
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Text(event.startAt, format: .dateTime.day()) // 19
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                Spacer(minLength: 4)
                
                // 🔹 Nested challenges card (smaller card inside hero card)
                if !challengesForEvent.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(Array(challengesForEvent.prefix(3))) { c in
                            HStack(spacing: 6) {
                                Text(c.title)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                
                                Text(rewardText(for: c))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.white.opacity(0.0))  // same light tile tint
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("No challenges added.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                }
                
                Spacer(minLength: 2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .frame(height: cardHeight)
    }
}
private func rewardText(for c: Challenge) -> String {
    var parts: [String] = []
    if let cash = c.rewardCash { parts.append(String(format: "$%.0f", cash)) }
    if let pts  = c.rewardPoints { parts.append("\(pts) pts") }
    return parts.isEmpty ? "—" : parts.joined(separator: " + ")
}

private extension View {
    @ViewBuilder
    func ifAvailableiOS17<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 17.0, *) { transform(self) } else { self }
    }
}

