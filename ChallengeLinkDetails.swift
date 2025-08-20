import SwiftUI

struct ChallengeLinkDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedChallenges: [Challenge]

    var targetEventTitle: String? = nil
    var onConfirmLink: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    // MARK: - Derived
    private var multiplierText: String {
        let c = max(0, selectedChallenges.count)
        guard c > 0 else { return "—" }
        let mult = 1.2 + Double(max(0, c - 1)) * 0.4
        return String(format: "%.1fx", mult)
    }

    var body: some View {
        NavigationStack {                       // << make sure we have a nav container
            VStack(spacing: 16) {
                // HEADER
                HStack {
                    Text("Review Challenges")
                        .font(.title3.bold())
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
                .padding(.horizontal)

                // LIST OR EMPTY STATE
                if selectedChallenges.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("No challenges added yet.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(selectedChallenges, id: \.id) { ch in
                            ChallengeRow(ch: ch) {
                                withAnimation {
                                    selectedChallenges.removeAll { $0.id == ch.id }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)

                    // ACTIONS
                    VStack(spacing: 16) {
                        Button {
                            // Optionally navigate back to add more picks
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Add Pick for \(multiplierText) Multiplier")
                                    .font(.subheadline.bold())
                            }
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                    .background(Capsule().fill(Color.black.opacity(0.15)))
                            )
                        }

                        Button(role: .destructive) {
                            if let onClear {
                                onClear()
                            } else {
                                withAnimation { selectedChallenges.removeAll() }
                            }
                        } label: {
                            Text("Clear Picks")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }

                // SUMMARY
                if !selectedChallenges.isEmpty {
                    SummaryCard(
                        eventTitle: targetEventTitle,
                        multiplierText: multiplierText
                    )
                    .padding(.horizontal)
                }

                // CONFIRM
                if !selectedChallenges.isEmpty {
                    Button {
                        onConfirmLink?()
                    } label: {
                        VStack(spacing: 2) {
                            Text("Link \(selectedChallenges.count) Challenge\(selectedChallenges.count > 1 ? "s" : "")")
                                .font(.headline.weight(.bold))
                            Text("Ready to attach to your event")
                                .font(.caption)
                                .opacity(0.9)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("ChallengeLink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {   // top-right close
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Row
private struct ChallengeRow: View {
    let ch: Challenge
    var onRemove: () -> Void

    private var rewardText: String {
        let cash = ch.rewardCash ?? 0
        let pts  = ch.rewardPoints ?? 0
        if cash > 0, pts > 0 { return "$\(Int(cash)) • +\(pts) pts" }
        if cash > 0 { return "$\(Int(cash))" }
        return "+\(pts) pts"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ChallengeAvatar()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(ch.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }

                if let eventName = ch.eventID, !eventName.isEmpty {
                    Text("Linked: \(eventName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not linked yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(rewardText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Avatar (default image only)
private struct ChallengeAvatar: View {
    var body: some View {
        Group {
            if let img = UIImage(named: "challenge_default") {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
                    .overlay(
                        Image(systemName: "sportscourt.fill")
                            .imageScale(.large)
                            .opacity(0.6)
                    )
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 2))
        .shadow(radius: 1)
    }
}

// MARK: - Summary
private struct SummaryCard: View {
    var eventTitle: String?
    var multiplierText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prizing & Link Summary")
                .font(.headline)

            if let eventTitle {
                HStack {
                    Text("Target Event")
                    Spacer()
                    Text(eventTitle).bold()
                }
                .font(.subheadline)
            }

            HStack {
                Text("Multiplier")
                Spacer()
                Text(multiplierText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.15)))
            }
            .font(.subheadline)

            Divider().padding(.top, 2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
