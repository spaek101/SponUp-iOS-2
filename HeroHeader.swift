import SwiftUI

struct HeroHeader: View {
    let eventsForToday: [Event]              // pass ALL of today's events here
    let acceptedChallenges: [Challenge]
    let userFirstName: String
    let userLastName: String

    @Binding var heroHeight: CGFloat         // parent controls this

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let todays = eventsForToday.sorted { $0.startAt < $1.startAt }

            VStack(spacing: 0) {


                if todays.count > 1 {
                    // Swipe between multiple games today
                    TabView {
                        ForEach(todays) { event in
                            heroCard(for: event)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: heroHeight)

                } else if let event = todays.first {
                    // Single game today
                    heroCard(for: event)

                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 16)
                        .padding(.top, 0)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Card builder
    @ViewBuilder
    private func heroCard(for event: Event) -> some View {
        let isToday = Calendar.current.isDateInToday(event.startAt)
        let bgName  = isToday ? "TodaysGame" : "UpcomingGame"

        ZStack(alignment: .center) {
            // Background image
            Image(bgName)
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.35),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                .clipped()

            // Centered content
            VStack(spacing: 10) {
                Text(event.title)
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(event.startAt, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                let challengesForEvent = acceptedChallenges.filter { $0.eventID == event.id }
                if !challengesForEvent.isEmpty {
                    VStack(alignment: .center, spacing: 6) {
                        ForEach(Array(challengesForEvent.prefix(3))) { c in
                            HStack(spacing: 6) {
                                // Challenge title
                                Text(c.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                // Reward info
                                Text(rewardText(for: c))
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                } else {
                    Text("No challenges added.")
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
        }
        .frame(height: heroHeight) // ensure each page respects the bound height
        
    }
}

// Helper for reward line
private func rewardText(for c: Challenge) -> String {
    var parts: [String] = []
    if let cash = c.rewardCash { parts.append(String(format: "$%.0f", cash)) }
    if let pts = c.rewardPoints { parts.append("\(pts) pts") }
    return parts.isEmpty ? "—" : parts.joined(separator: " + ")
}
