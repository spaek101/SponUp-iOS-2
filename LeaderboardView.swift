import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var leaderboardVM: LeaderboardViewModel

    // Pull from VM
    private var entries: [LeaderboardEntry] { leaderboardVM.entries }

    // Order by points DESC, then name ASC, then id ASC (stable for exact ties). Take top 100.
    private var top100ByPoints: [LeaderboardEntry] {
        let s = entries.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            let nameCmp = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameCmp != .orderedSame { return nameCmp == .orderedAscending }
            return $0.id < $1.id
        }
        return Array(s.prefix(100))
    }

    // Ranks from position (1-based)
    private var podium: [IndexedEntry] {
        Array(top100ByPoints.prefix(3)).enumerated().map { idx, e in
            IndexedEntry(id: e.id, rank: idx + 1, entry: e)
        }
    }
    private var others: [IndexedEntry] {
        Array(top100ByPoints.dropFirst(3)).enumerated().map { idx, e in
            IndexedEntry(id: e.id, rank: idx + 4, entry: e)
        }
    }

    var body: some View {
        ScrollView {
            if top100ByPoints.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading leaderboard…")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 80)
            } else {
                VStack(spacing: 24) {
                    // PODIUM (1–3)
                    HStack(alignment: .bottom, spacing: 16) {
                        if podium.count > 1 { PodiumCard(entry: podium[1].entry, rank: podium[1].rank).offset(y: 12) }
                        if podium.count > 0 { PodiumCard(entry: podium[0].entry, rank: podium[0].rank).offset(y: -12) }
                        if podium.count > 2 { PodiumCard(entry: podium[2].entry, rank: podium[2].rank).offset(y: 12) }
                    }
                    .padding(.horizontal, 16)

                    TableHeader()
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    // Remaining ranks
                    LazyVStack(spacing: 12) {
                        ForEach(others, id: \.id) { item in
                            RankRow(entry: item.entry, rank: item.rank)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.top, 60)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Image("leaderboard_bg")
                .resizable()
                .scaledToFill()
                .opacity(0.15)         // light, opaque feel
                .ignoresSafeArea()     // extend behind nav/tab bars
        )
        .task {
            if leaderboardVM.entries.isEmpty {
                await leaderboardVM.refresh()
            }
        }
        .refreshable {
            await leaderboardVM.refresh()
        }
    }
}

// Stable row model for ForEach
private struct IndexedEntry: Identifiable {
    let id: String
    let rank: Int
    let entry: LeaderboardEntry
}

// MARK: – Podium card
private struct PodiumCard: View {
    let entry: LeaderboardEntry
    let rank: Int

    // Foil background per rank
    private var bgAssetName: String? {
        switch rank {
        case 1: return "firstplace_bg"   // gold
        case 2: return "secondplace_bg"  // silver
        case 3: return "thirdplace_bg"   // bronze
        default: return nil              // anything else → white fill
        }
    }

    // Medal dot color (for the corner badge)
    private var medalColor: Color {
        switch rank {
        case 1: return Color(red: 0.98, green: 0.80, blue: 0.22)
        case 2: return Color(red: 0.85, green: 0.85, blue: 0.88)
        case 3: return Color(red: 0.90, green: 0.58, blue: 0.24)
        default: return .clear
        }
    }

    // Text color tuned for each foil
    private var titleColor: Color {
        switch rank {
        case 1: return Color(red: 0.0, green: 0.12, blue: 0.25)    // deep navy on gold
        case 2: return .black                                       // black on silver
        case 3: return .black                                      //  on bronze
        default: return .primary
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: "https://i.pravatar.cc/160?u=athlete\(entry.id)")) { phase in
                (phase.image ?? Image(systemName: "person.fill"))
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: 70, height: 70)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))

            Text(entry.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(titleColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 80)
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)

            Text(entry.points.formattedWithSeparator + " pts")
                .font(.caption2.weight(.semibold))
                .foregroundColor(titleColor.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .padding()
        .frame(width: 110, height: 175)
        .background(
            ZStack {
                if let bg = bgAssetName {
                    Image(bg)
                        .resizable()
                        .scaledToFill() // preserves aspect ratio, no distortion
                        .overlay(
                            // subtle bottom scrim to help text pop on bright foil
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.15),
                                    Color.black.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                } else {
                    Color.white
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1) // subtle edge
        )
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
        .overlay(alignment: .topTrailing) {
            Text("\(rank)")
                .font(.caption.bold())
                .foregroundColor(.black)
                .padding(6)
                .background(medalColor)
                .clipShape(Circle())
                .offset(x: 8, y: -8)
        }
    }
}



// MARK: – Table header
private struct TableHeader: View {
    var body: some View {
        HStack {
            Text("Rank").frame(width: 40, alignment: .leading)
            Text("User").frame(maxWidth: .infinity, alignment: .leading)
            Text("Points").frame(width: 80, alignment: .trailing)
        }
        .font(.caption.bold())
        .padding(10)
        .background(Color.white.opacity(0.20))
        .cornerRadius(8)
    }
}

// MARK: – Rank row
private struct RankRow: View {
    let entry: LeaderboardEntry
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .frame(width: 40, alignment: .leading)

            HStack(spacing: 8) {
                AsyncImage(url: URL(string: "https://i.pravatar.cc/160?u=athlete\(entry.id)")) { phase in
                    (phase.image ?? Image(systemName: "person.fill"))
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                Text(entry.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.points.formattedWithSeparator)
                .frame(width: 80, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 2)
    }
}
