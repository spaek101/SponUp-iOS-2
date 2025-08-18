import SwiftUI

struct FundingCartView: View {
    @Environment(\.dismiss) private var dismiss

    // Bindings from parent
    @Binding var fundedChallenges: [Challenge]
    @Binding var walletBalance: Double
    @Binding var fundingTargets: [String: Set<String>]   // challengeID -> athleteIDs

    // Use your existing logic via this closure
    let nameForAthleteID: (String) -> String

    // Callbacks
    let onConfirmFunding: () -> Void
    let onTopUp: () -> Void

    // MARK: - Totals
    private var totalFunding: Double {
        fundedChallenges.reduce(0) { $0 + challengeFundingValue($1) }
    }
    private var remaining: Double { walletBalance - totalFunding }

    private func challengeFundingValue(_ c: Challenge) -> Double {
        switch c.difficulty {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 20
        }
    }

    // MARK: - Helpers
    private func recipientsText(for challenge: Challenge) -> String {
        // Works whether id is String or String?
        guard let cid = challenge.id, let ids = fundingTargets[cid], !ids.isEmpty else {
            return "—"
        }
        let names = ids.map(nameForAthleteID).filter { !$0.isEmpty }.sorted()
        return names.isEmpty ? "—" : names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                Text("\(fundedChallenges.count) item(s) in cart")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top)
                    .padding(.horizontal)

                // List
                List {
                    ForEach(fundedChallenges, id: \.id) { challenge in
                        HStack(alignment: .top, spacing: 12) {
                            Image(challenge.imageName)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(challenge.title).font(.headline)
                                    Spacer()
                                    Text("$\(Int(challengeFundingValue(challenge)))").font(.headline)
                                }

                                Text("For: \(recipientsText(for: challenge))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)

                                HStack {
                                    Text("\(challenge.rewardPoints ?? 0) pts")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button("Remove") {
                                        withAnimation {
                                            fundedChallenges.removeAll { $0.id == challenge.id }
                                            if let cid = challenge.id {
                                                fundingTargets[cid] = nil
                                            }
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)

                if remaining < 0 {
                    Text("⚠️ Insufficient funds")
                        .foregroundColor(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.brown.opacity(0.7))
                        .cornerRadius(8)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("Wallet Balance"); Spacer()
                        Text(String(format: "$%.2f", walletBalance))
                    }
                    .foregroundColor(.secondary)

                    HStack {
                        Text("Total Funding"); Spacer()
                        Text(String(format: "$%.2f", totalFunding)).bold()
                    }

                    HStack {
                        Text("Remaining"); Spacer()
                        Text(
                            remaining < 0
                            ? String(format: "−$%.2f", abs(remaining))
                            : String(format: "$%.2f", remaining)
                        )
                        .foregroundColor(remaining < 0 ? .red : .primary)
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: onTopUp) {
                        Text("Top Up Wallet")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: onConfirmFunding) {
                        Text("Confirm Funding")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(remaining >= 0 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(remaining < 0)
                }
                .padding()
            }
            .navigationTitle("Funding Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
