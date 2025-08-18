import SwiftUI

struct WalletView: View {
    // MARK: – Demo State (wire these up to your real data)
    @State private var walletBalance: Double = 35.00
    @State private var selectedFilter: Filter = .all

    private var activities: [Activity] = [
        .init(type: .funded,  title: "Funded challenge: 2 Home Runs",       subtitle: "To Mason R. • Jul. 22", amount: -5),
        .init(type: .funded,  title: "Funded challenge: Run 5 Miles",        subtitle: "To Trevor L. • Jul. 20", amount: -10),
        .init(type: .expired, title: "Expired challenge: Score 3 Goals",     subtitle: "Olivia W. • Jul. 15",    amount: -20),
    ]

    // Filtered view
    private var filtered: [Activity] {
        switch selectedFilter {
        case .all:     return activities
        case .funded:  return activities.filter { $0.type == .funded }
        case .expired: return activities.filter { $0.type == .expired }
        }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all     = "All"
        case funded  = "Funded"
        case expired = "Expired"
        var id: String { rawValue }
    }

    struct Activity: Identifiable {
        enum Kind { case funded, expired }
        let id = UUID()
        let type: Kind
        let title: String
        let subtitle: String
        let amount: Double

        var formattedDate: String {
            guard let raw = subtitle.split(separator: "•").last?
                .trimmingCharacters(in: .whitespaces) else { return subtitle }
            let inFmt = DateFormatter(); inFmt.dateFormat = "MMM. d"; inFmt.locale = .init(identifier: "en_US"); inFmt.defaultDate = Date()
            let outFmt = DateFormatter(); outFmt.locale = .init(identifier: "en_US"); outFmt.dateStyle = .long
            return inFmt.date(from: raw).map(outFmt.string(from:)) ?? raw
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Available Balance Card ─────────────────────────
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Balance")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text(String(format: "$%.2f", walletBalance))
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button("Top Up") { /* present top-up flow */ }
                            .font(.body.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    if walletBalance < 50 {
                        Text("⚠️ Low balance – some challenges may be unfundable")
                            .font(.footnote)
                            .foregroundColor(.yellow.opacity(0.9))
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(Color.yellow.opacity(0.3))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(red: 0/255, green: 0/255, blue: 128/255)) // Navy blue
                .cornerRadius(16)
                .padding(.horizontal)

                // ── Recent Wallet Activity ───────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Wallet Activity")
                        .font(.headline)
                        .padding(.horizontal)

                    Picker("", selection: $selectedFilter) {
                        ForEach(Filter.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(filtered) { act in
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: act.type == .funded
                                      ? "dollarsign.circle.fill"
                                      : "clock.arrow.circlepath")
                                    .font(.system(size: 24))
                                    .foregroundColor(act.type == .funded ? .green : .gray)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(act.title)
                                        .font(.subheadline.bold())
                                    Text(act.formattedDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                let sign: String = {
                                    if act.type == .expired { return "+" }
                                    else if act.amount < 0 { return "−" }
                                    else { return "" }
                                }()
                                let amt = String(format: "$%.2f", abs(act.amount))
                                let color: Color = (sign == "−" ? .red : .primary)

                                Text("\(sign) \(amt)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(color)
                            }
                            .padding(.horizontal)
                        }

                        if filtered.isEmpty {
                            Text("No \(selectedFilter.rawValue.lowercased()) activity")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 40)
                        }
                    }
                }
            }
            .padding(.top)
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Image("leaderboard_bg")
                .resizable()
                .scaledToFill()
                .opacity(0.15)
                .ignoresSafeArea()
        )
    }
}
