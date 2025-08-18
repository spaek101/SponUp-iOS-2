import SwiftUI
import Combine

// MARK: – Medal helpers (kept; unused here but harmless)
private extension Int {
    var medalColor: Color {
        switch self {
        case 1: return Color(red: 0.98, green: 0.80, blue: 0.22)
        case 2: return Color(red: 0.85, green: 0.85, blue: 0.88)
        case 3: return Color(red: 0.90, green: 0.58, blue: 0.24)
        default: return Color(.systemGray5)
        }
    }
    var medalText: String {
        switch self {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case 5: return "5th"
        default: return "\(self)"
        }
    }
}

// MARK: – LeaderboardStrip (text-only + auto-scroll)
struct LeaderboardStrip: View {
    let topEntries: [LeaderboardEntry]
    var onTapLeaderboard: () -> Void = { }
    var tapAnywhere: Bool = false

    // ── Auto-scroll state/tunables ─────────────────────────────
    @State private var autoOffset: CGFloat = 0           // animated offset
    @State private var contentWidth: CGFloat = 1         // width of one row
    @State private var isPaused: Bool = false            // pause auto scroll
    @State private var lastTick: Date = Date()           // for delta timing
    @GestureState private var dragOffset: CGFloat = 0    // live drag

    private let speed: CGFloat = 28                      // pts/sec
    private let resumeDelay: TimeInterval = 1.2          // after drag ends

    // Sort by rank (if present), else by points DESC, then name ASC
    private var sortedAll: [LeaderboardEntry] {
        topEntries.sorted {
            let r0 = $0.rank ?? .max
            let r1 = $1.rank ?? .max
            if r0 != r1 { return r0 < r1 }
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // Take only the top 50 after sorting
    private var top50: [LeaderboardEntry] {
        Array(sortedAll.prefix(50))
    }

    private struct DisplayItem: Identifiable {
        let id: String
        let rank: Int
        let name: String
        let points: Int
    }

    // Re-number ranks starting at 1 within the top 50
    private var displayItems: [DisplayItem] {
        top50.enumerated().map { idx, e in
            DisplayItem(
                id: e.id,
                rank: idx + 1,       // <-- restart numbering from 1
                name: e.name,
                points: e.points
            )
        }
    }

    var body: some View {
        if tapAnywhere {
            Button(action: onTapLeaderboard) { stripContent() }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("View leaderboard")
        } else {
            stripContent()
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("View leaderboard")
                .onTapGesture { onTapLeaderboard() }
        }
    }

    // MARK: - Auto-scrolling marquee content
    private func stripContent() -> some View {
        ZStack {
            // background pill
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
            

            
            GeometryReader { geo in
                // The “row” of items (once)
                let leadingInset: CGFloat  = 16
                let trailingInset: CGFloat = 24

                let row = HStack(spacing: 24) {
                    Color.clear.frame(width: leadingInset)      // left padding

                    // 👇 New prefix label
                    Text("Top 50 Athletes...")
                        .font(.caption.bold())
                        .foregroundColor(.black)
                        .fixedSize(horizontal: true, vertical: false)

                    ForEach(displayItems) { item in
                        Text("\(item.rank). \(item.name): \(item.points.formattedWithSeparator) pts")
                            .font(.caption)
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Color.clear.frame(width: trailingInset)     // right padding
                }


                // Gesture: pause while dragging and add manual offset
                let drag = DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                        isPaused = true
                    }
                    .onEnded { value in
                        autoOffset += value.translation.width
                        DispatchQueue.main.asyncAfter(deadline: .now() + resumeDelay) {
                            isPaused = false
                            lastTick = Date()
                        }
                    }

                // Two rows back-to-back → seamless loop
                HStack(spacing: 24) {
                    row
                        .background(WidthReader()) // measure single-row width (now includes insets)
                    row
                }
                .offset(x: effectiveOffset())
                .padding(.vertical, 10)               // ← keep only vertical
                // .padding(.horizontal, 12)          // ← remove this line
                .onPreferenceChange(WidthKey.self) { w in
                    contentWidth = max(w, geo.size.width + 1)
                }
                .onAppear { lastTick = Date() }
                .onReceive(timer) { now in
                    guard !isPaused, contentWidth > 0 else { lastTick = now; return }
                    let dt = now.timeIntervalSince(lastTick)
                    lastTick = now
                    autoOffset -= speed * CGFloat(dt)
                    if autoOffset <= -contentWidth { autoOffset += contentWidth }
                }
                .gesture(drag)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .mask(
                    LinearGradient(                    // left is solid, right fades out
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.94),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36) // a bit taller for touch comfort
    }

    // Normalize offset into [-contentWidth, 0]
    private func effectiveOffset() -> CGFloat {
        guard contentWidth > 0 else { return 0 }
        var x = autoOffset + dragOffset
        x = x.truncatingRemainder(dividingBy: contentWidth)
        if x > 0 { x -= contentWidth }
        return x
    }

    // 60 Hz “tick”
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    }
}

// MARK: – Width measuring helper
private struct WidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
        }
    }
}
private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
