import SwiftUI

struct ChallengeLinkDetails: View {
    @Environment(\.dismiss) private var dismiss

    // Selected challenges (binding from parent)
    @Binding var selectedChallenges: [Challenge]

    // Only pass future events (parent filters if desired)
    var upcomingEvents: [Event]

    // Live lookup from parent so counts stay fresh between links
    var existingLinkedCount: (String) -> Int

    // Callbacks
    var onLinkSelection: (([(challengeId: String, eventId: String)]) -> Void)? = nil
    var onConfirmLink: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    // Notify parent to truly unaccept (so card reverts to "Accept")
    var onUnaccept: ((String, String?) -> Void)? = nil   // (challengeID, previousEventID)

    // Track which event each challenge is linked to (locally in this sheet)
    @State private var selectedEventIdByChallenge: [String: String] = [:]

    // CONFIG
    private let maxLinksPerEvent = 3

    // MARK: - Totals
    private var totalCash: Int {
        selectedChallenges.reduce(0) { $0 + Int($1.rewardCash ?? 0) }
    }
    private var totalPoints: Int {
        selectedChallenges.reduce(0) { $0 + ($1.rewardPoints ?? 0) }
    }

    // Count how many would be linked to an event *if confirmed now*
    // = base existing + rows moved into this event − rows moved out of this event.
    private func currentLinkCount(for eventID: String) -> Int {
        let base = existingLinkedCount(eventID)
        var delta = 0

        for ch in selectedChallenges {
            guard let cid = ch.id else { continue }
            let originalOpt: String? = ch.eventID
            let chosenOpt: String?   = selectedEventIdByChallenge[cid] ?? originalOpt

            let wasIn = (originalOpt == eventID)
            let nowIn = (chosenOpt   == eventID)

            if !wasIn && nowIn { delta += 1 }   // moved into this event
            if  wasIn && !nowIn { delta -= 1 }  // moved out of this event
        }
        return max(0, base + delta)
    }

    // Remaining slots for an event (0...max)
    private func remainingSlots(for eventID: String?) -> Int {
        guard let eventID = eventID else { return 0 }
        return max(0, maxLinksPerEvent - currentLinkCount(for: eventID))
    }

    // Make a binding to the selected event id for a specific challenge
    private func bindingForEventId(_ challengeId: String?) -> Binding<String?> {
        Binding<String?>(
            get: {
                guard let id = challengeId else { return nil }
                return selectedEventIdByChallenge[id]
            },
            set: { newValue in
                guard let id = challengeId else { return }
                if let v = newValue, !v.isEmpty {
                    selectedEventIdByChallenge[id] = v
                } else {
                    selectedEventIdByChallenge.removeValue(forKey: id)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // HEADER
                HStack {
                    Text("Review Challenges").font(.title3.bold())
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
                        // Using enumerated keeps your removal-by-index logic intact
                        ForEach(Array(selectedChallenges.enumerated()), id: \.offset) { idx, ch in
                            ChallengeRow(
                                ch: ch,
                                selectedEventId: bindingForEventId(ch.id),
                                upcomingEvents: upcomingEvents,
                                // Capacity helpers
                                remainingSlots: { eid in remainingSlots(for: eid) },                    // (String?) -> Int
                                usedCount: { eid in maxLinksPerEvent - remainingSlots(for: eid) },       // (String?) -> Int
                                maxLinksPerEvent: maxLinksPerEvent,
                                onRemove: {
                                    withAnimation {
                                        selectedChallenges.remove(at: idx)
                                        if let id = ch.id { selectedEventIdByChallenge.removeValue(forKey: id) }
                                    }
                                    if let id = ch.id {
                                        onUnaccept?(id, ch.eventID)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)

                    // ACTIONS
                    VStack(spacing: 16) {
                        Button(role: .destructive) {
                            // notify parent for each removed challenge (include eventID)
                            selectedChallenges.forEach { ch in
                                if let id = ch.id { onUnaccept?(id, ch.eventID) }
                            }

                            if let onClear {
                                onClear()
                            } else {
                                withAnimation {
                                    selectedChallenges.removeAll()
                                    selectedEventIdByChallenge.removeAll()
                                }
                            }
                        } label: {
                            Text("Clear Picks")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }

                // SUMMARY
                if !selectedChallenges.isEmpty {
                    SummaryCard(totalCash: totalCash, totalPoints: totalPoints)
                        .padding(.horizontal)
                }

                // CONFIRM (links each chosen challenge to the chosen event)
                if !selectedChallenges.isEmpty {
                    Button {
                        // Build mapping (challengeId → eventId) for rows where the user chose an event
                        let pairs: [(String, String)] = selectedChallenges.compactMap { ch in
                            guard let cid = ch.id,
                                  let eid = selectedEventIdByChallenge[cid],
                                  !eid.isEmpty
                            else { return nil }
                            return (cid, eid)
                        }

                        // 1) Let parent write to Firestore
                        onLinkSelection?(pairs)

                        // 2) Remove only the linked ones from the sheet (and parent via binding)
                        let linkedIDs = Set(pairs.map { $0.0 })
                        withAnimation {
                            selectedChallenges.removeAll { ch in
                                guard let id = ch.id else { return false }
                                return linkedIDs.contains(id)
                            }
                            linkedIDs.forEach { selectedEventIdByChallenge.removeValue(forKey: $0) }
                        }

                        // 3) Optional existing hook (e.g., close the sheet/banners)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .background(Color(.systemBackground))
            .onAppear {
                // Pre-load selections from the challenge if it already has an eventID
                for ch in selectedChallenges {
                    if let cid = ch.id, let eid = ch.eventID {
                        selectedEventIdByChallenge[cid] = eid
                    }
                }
            }
        }
    }
}

// MARK: - Row
private struct ChallengeRow: View {
    let ch: Challenge
    @Binding var selectedEventId: String?
    var upcomingEvents: [Event]

    var remainingSlots: (String?) -> Int
    var usedCount: (String?) -> Int
    var maxLinksPerEvent: Int

    var onRemove: () -> Void

    @State private var showEventPicker = false
    @State private var showNoEventsAlert = false

    // Helpers that were missing or moved out of scope:

    private var rewardText: String {
        let cash = ch.rewardCash ?? 0
        let pts  = ch.rewardPoints ?? 0
        if cash > 0, pts > 0 { return "$\(Int(cash)) • +\(pts) pts" }
        if cash > 0 { return "$\(Int(cash))" }
        return "+\(pts) pts"
    }

    private func eventTitle(for id: String?) -> String? {
        guard let id else { return nil }
        return upcomingEvents.first(where: { $0.id == id })?.title
    }

    private var buttonLabel: String {
        if let title = eventTitle(for: selectedEventId) {
            if let eid = selectedEventId {
                let used = usedCount(eid)
                return "Linked to \(title) (\(used)/\(maxLinksPerEvent))"
            }
            return "Linked to \(title)"
        } else if upcomingEvents.isEmpty {
            return "No upcoming events to link"
        } else {
            let allFull = upcomingEvents.allSatisfy { ev in remainingSlots(ev.id) == 0 }
            if allFull { return "No events to link" }
            return "Link to an event"
        }
    }

    private func eventPickerLabel(for title: String, slots: Int) -> String {
        if slots == 0 { return "\(title) — Full" }
        if slots == 1 { return "\(title) — 1 left" }
        return "\(title) — \(slots) left"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ChallengeAvatar(ch: ch)

            VStack(alignment: .leading, spacing: 6) {
                Text(ch.title)
                    .font(.headline)
                    .lineLimit(1)

                // Guarded button: no empty picker, show alert when none/ full
                Button {
                    let allFull = upcomingEvents.allSatisfy { ev in remainingSlots(ev.id) == 0 }
                    if upcomingEvents.isEmpty || allFull {
                        showNoEventsAlert = true
                    } else {
                        showEventPicker = true
                    }
                } label: {
                    Text(buttonLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .foregroundColor(selectedEventId == nil ? .blue : .green)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Select Event", isPresented: $showEventPicker, titleVisibility: .visible) {
                    ForEach(upcomingEvents, id: \.id) { event in
                        let slots = remainingSlots(event.id)
                        let isThisRowsCurrent = (selectedEventId == event.id)
                        let disabled = (slots == 0 && !isThisRowsCurrent)

                        Button(eventPickerLabel(for: event.title, slots: slots)) {
                            if !disabled { selectedEventId = event.id }
                        }
                        .disabled(disabled)
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .alert("You must first create an event", isPresented: $showNoEventsAlert) {
                    Button("OK", role: .cancel) { }
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

// MARK: - Avatar
private struct ChallengeAvatar: View {
    let ch: Challenge

    private var isCashChallenge: Bool {
        (ch.rewardCash ?? 0) > 0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15)) // background circle
                .frame(width: 52, height: 52)

            if isCashChallenge {
                Image(systemName: "dollarsign.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.yellow)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
        )
        .shadow(radius: 1)
    }
}

// MARK: - Summary
private struct SummaryCard: View {
    var totalCash: Int
    var totalPoints: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prizing & Link Summary").font(.headline)

            HStack {
                Text("Total Cash Value")
                Spacer()
                Text("$\(totalCash)").bold()
            }
            .font(.subheadline)

            HStack {
                Text("Total Points Value")
                Spacer()
                Text("+\(totalPoints) pts").bold()
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
