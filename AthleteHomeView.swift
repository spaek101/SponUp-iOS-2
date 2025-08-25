import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UIKit

// MARK: - AthleteHomeView

struct AthleteHomeView: View {
    let userFullName: String

    @EnvironmentObject private var tierVM: TierViewModel
    @EnvironmentObject private var cartVM: CartViewModel
    @EnvironmentObject private var leaderboardVM: LeaderboardViewModel

    @State private var selectedFilter: SuggestedFilter = .eventFocus

    // Backend-loaded data
    @State private var events: [Event] = []
    @State private var acceptedChallenges: [Challenge] = []
    @StateObject private var sponsoredVM = SponsoredChallengesViewModel()

    // AI-generated challenges (reward + training)
    @State private var aiRewardChallenges: [Challenge] = []
    @State private var aiTrainingChallenges: [Challenge] = []

    @State private var heroHeaderHeight: CGFloat = 160

    // Loading gate to prevent "No games" flicker
    @State private var eventsLoaded = false

    // Toast UI
    @State private var toastMessage: String? = nil
    @State private var toastTimer: Timer?

    @State private var userID: String? = Auth.auth().currentUser?.uid

    // Bottom strip state
    @State private var pendingAccepted: [Challenge] = []
    @State private var showChallengeLink = false

    // Present details as a sheet (prevents frozen UI)
    @State private var navigateToLinkDetails = false

    // The list passed into ChallengeLinkDetails
    @State private var selectedChallenges: [Challenge] = []

    private let db = Firestore.firestore()

    private func isAccepted(_ ch: Challenge) -> Bool {
        guard let id = ch.id else { return false }
        let key = "\(ch.type.rawValue)|\(id)"
        return acceptedChallenges.contains { ac in
            guard let aid = ac.id else { return false }
            return "\(ac.type.rawValue)|\(aid)" == key
        }
    }

    // How many are already linked per event (for capacity display in sheet)
    private var existingLinkedCounts: [String: Int] {
        Dictionary(grouping: acceptedChallenges.compactMap { $0.eventID }) { $0 }
            .mapValues { $0.count }
    }

    var body: some View {
        // ⬇️ Keep these as tiny locals to ease type inference
        let userFirstName = userFullName.components(separatedBy: " ").first ?? ""
        let userLastName  = userFullName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        let cashTotal: Int = {
            // Avoid reduce over optionals with generics that make the compiler sad
            let sum = acceptedChallenges.reduce(0.0) { $0 + ($1.rewardCash ?? 0) }
            return Int(sum)
        }()

        return NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        WelcomeHeader(
                            userFirstName: userFirstName,
                            userLastName: userLastName,
                            points: tierVM.points,
                            cash: cashTotal
                        )
                        .padding(.top, 0)

                        Group {
                            if !eventsLoaded {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(.systemGray6))
                                    .frame(height: heroHeaderHeight)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .redacted(reason: .placeholder)
                            } else {
                                let cal = Calendar.current
                                let todaysEvents = events
                                    .filter { cal.isDateInToday($0.startAt) }
                                    .sorted { $0.startAt < $1.startAt }

                                let listToShow: [Event] = !todaysEvents.isEmpty
                                    ? todaysEvents
                                    : (events.filter { $0.startAt > Date() }
                                            .sorted { $0.startAt < $1.startAt }
                                            .prefix(1).map { $0 })

                                HeroHeader(
                                    eventsForToday: listToShow,
                                    acceptedChallenges: acceptedChallenges,
                                    userFirstName: userFirstName,
                                    userLastName: userLastName,
                                    heroHeight: $heroHeaderHeight
                                )
                                .padding(.horizontal, 0)
                                .padding(.top, 20)
                                .padding(.bottom, 150)
                            }
                        }

                        Color.clear.frame(height: 12)

                        // Tabs row
                        VStack(spacing: AppSpacing.md) {
                            HStack(spacing: AppSpacing.md) {
                                Button("Challenge") { 
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedFilter = .eventFocus
                                    }
                                    HapticManager.impact(style: .light)
                                }
                                .modernTab(isSelected: selectedFilter == .eventFocus)
                                
                                Button("Training") { 
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedFilter = .training
                                    }
                                    HapticManager.impact(style: .light)
                                }
                                .modernTab(isSelected: selectedFilter == .training)
                                
                                Button("Sponsored") { 
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedFilter = .sponsored
                                    }
                                    HapticManager.impact(style: .light)
                                }
                                .modernTab(isSelected: selectedFilter == .sponsored)
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)

                        // Suggested Challenges content
                        if selectedFilter == .eventFocus {
                            if !aiRewardChallenges.isEmpty {
                                SuggestedChallengesSection(
                                    challenges: $aiRewardChallenges,
                                    selectedFilter: $selectedFilter,
                                    headerType: "rewards",
                                    onClaim: acceptChallenge,
                                    onShowMore: regenerateRewardChallenges
                                ) { challenge, _ in
                                    AnyView(
                                        ChallengeCardView(
                                            challenge: challenge,
                                            onClaim: acceptChallenge,
                                            fundButton: false,
                                            isFunded: isAccepted(challenge),
                                            showCash: false
                                        )
                                    )
                                }
                                .padding(.horizontal)
                            }
                        } else if selectedFilter == .training, !aiTrainingChallenges.isEmpty {
                            SuggestedChallengesSection(
                                challenges: $aiTrainingChallenges,
                                selectedFilter: $selectedFilter,
                                headerType: "training",
                                onClaim: acceptChallenge,
                                onShowMore: regenerateTrainingChallenges
                            ) { challenge, _ in
                                AnyView(
                                    ChallengeCardView(
                                        challenge: challenge,
                                        onClaim: acceptChallenge,
                                        fundButton: false,
                                        isFunded: isAccepted(challenge),
                                        showCash: false
                                    )
                                )
                            }
                            .padding(.horizontal)
                        } else if selectedFilter == .sponsored {
                            SponsoredTab(
                                challenges: Binding<[Challenge]>(   // ⬅️ explicit generic
                                    get: { sponsoredVM.sponsored },
                                    set: { sponsoredVM.sponsored = $0 }
                                ),
                                selectedFilter: $selectedFilter,
                                acceptedChallenges: acceptedChallenges,
                                onClaim: acceptChallenge
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                // Toast overlay
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        Text(message)
                            .font(.callout)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 50)
                            .transition(.opacity)
                    }
                    .animation(.easeInOut, value: toastMessage)
                }
            }
            .background(
                AnimatedBackground()
                    .ignoresSafeArea()
            )
            .tint(.white)
            .onAppear {
                if userID == nil { userID = Auth.auth().currentUser?.uid }
                loadUserAcceptedChallenges()
                loadEvents()
                generateAIChallenges()

                if leaderboardVM.entries.isEmpty {
                    leaderboardVM.refresh()
                }

                if let uid = userID {
                    sponsoredVM.start(for: uid)
                }
            }
            .onDisappear { sponsoredVM.stop() }

            // Bottom banner
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showChallengeLink && !pendingAccepted.isEmpty {
                    ChallengeLinkBanner(
                        avatars: linkModels(),
                        headline: "Link",
                        subheadline: "Tap to review",
                        maxVisibleAvatars: 6,
                        onPrimaryTap: {
                            // prefill sheet with banner items
                            selectedChallenges = pendingAccepted
                            showChallengeLink = false
                            navigateToLinkDetails = true
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                showChallengeLink = false
                            }
                        }
                    )
                    .onTapGesture {
                        selectedChallenges = pendingAccepted
                        showChallengeLink = false
                        navigateToLinkDetails = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                } else {
                    Color.clear.frame(height: 0)
                }
            }

            // SHEET: ChallengeLinkDetails
            .sheet(isPresented: $navigateToLinkDetails, onDismiss: {
                // Always clear temp list and keep strip closed
                selectedChallenges.removeAll()
                showChallengeLink = false
            }) {
                ChallengeLinkDetails(
                    selectedChallenges: $selectedChallenges,
                    upcomingEvents: events,
                    existingLinkedCount: { eid in existingLinkedCounts[eid] ?? 0 }, // ✅ correct label + closure
                    onLinkSelection: { pairs in

                        // Firestore txn per pair (capacity-safe), with optimistic local updates
                        for (cid, eid) in pairs {
                            let ref = db.collection("events").document(eid)

                            db.runTransaction({ (txn, errorPointer) -> Any? in
                                let snap: DocumentSnapshot
                                do { snap = try txn.getDocument(ref) } catch {
                                    errorPointer?.pointee = error as NSError
                                    return nil
                                }

                                var ids = (snap.get("challengeIDs") as? [String]) ?? []
                                if !ids.contains(cid) && ids.count < 3 {
                                    ids.append(cid)
                                    txn.updateData(["challengeIDs": ids], forDocument: ref)
                                } else if ids.count >= 3 {
                                    errorPointer?.pointee = NSError(
                                        domain: "LinkChallenges",
                                        code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "Event is at capacity."]
                                    )
                                    return nil
                                }
                                return nil
                            }) { _, err in
                                if let err = err {
                                    print("Transaction failed: \(err.localizedDescription)")
                                    return
                                }

                                // Persist user's accepted challenge with eventID
                                if let uid = userID {
                                    db.collection("users")
                                        .document(uid)
                                        .collection("acceptedChallenges")
                                        .document(cid)
                                        .setData(["eventID": eid], merge: true)
                                }

                                // Remove from AI lists (optional)
                                if let i = aiRewardChallenges.firstIndex(where: { $0.id == cid }) {
                                    aiRewardChallenges.remove(at: i)
                                }
                                if let j = aiTrainingChallenges.firstIndex(where: { $0.id == cid }) {
                                    aiTrainingChallenges.remove(at: j)
                                }

                                // Hide from Sponsored feed
                                if let uid = userID {
                                    db.collection("users")
                                        .document(uid)
                                        .collection("challenges")
                                        .document(cid)
                                        .setData([
                                            "state": "inProgress",
                                            "eventID": eid
                                        ], merge: true)
                                }

                                // ✅ Optimistic LOCAL STATE so event cards update immediately
                                DispatchQueue.main.async {
                                    // Move/update challenge in acceptedChallenges
                                    if let aidx = acceptedChallenges.firstIndex(where: { $0.id == cid }) {
                                        // If previously linked to a different event, remove from that event
                                        if let oldEid = acceptedChallenges[aidx].eventID,
                                           let oldIdx = events.firstIndex(where: { $0.id == oldEid }) {
                                            events[oldIdx].challengeIDs.removeAll { $0 == cid }
                                        }
                                        acceptedChallenges[aidx].eventID = eid
                                    } else if let ch = pendingAccepted.first(where: { $0.id == cid }) {
                                        var copy = ch
                                        copy.eventID = eid
                                        acceptedChallenges.append(copy)
                                    }

                                    // Add to new event’s list
                                    if let eidx = events.firstIndex(where: { $0.id == eid }) {
                                        if !events[eidx].challengeIDs.contains(cid) {
                                            events[eidx].challengeIDs.append(cid)
                                        }
                                    }
                                }
                            }
                        }

                        // 🔒 Close strip + sheet and clear temp selections
                        withAnimation {
                            pendingAccepted.removeAll()
                            selectedChallenges.removeAll()
                            showChallengeLink = false
                            navigateToLinkDetails = false
                        }
                    },
                    onConfirmLink: {
                        withAnimation {
                            pendingAccepted.removeAll()
                            selectedChallenges.removeAll()
                            showChallengeLink = false
                            navigateToLinkDetails = false
                        }
                    },
                    onClear: {
                        selectedChallenges.removeAll()
                    },
                    onUnaccept: { cid, eid in
                        unacceptChallenge(challengeID: cid, eventID: eid)
                    }
                )
                .interactiveDismissDisabled(false)
            }
        }
    }

    // MARK: — AI challenge generation

    private func generateAIChallenges() {
        loadRewardChallenges()
        loadTrainingChallenges()
    }

    private func loadRewardChallenges() {
        aiRewardChallenges = (0..<8).map { _ in generateSingleAIChallenge(type: .reward) }
    }
    private func regenerateRewardChallenges() { loadRewardChallenges() }

    private func loadTrainingChallenges() {
        aiTrainingChallenges = (0..<8).map { _ in generateSingleAIChallenge(type: .training) }
    }
    private func regenerateTrainingChallenges() { loadTrainingChallenges() }

    private func generateSingleAIChallenge(type: ChallengeType) -> Challenge {
        let title: String
        if type == .training {
            let trainingTitles = [
                "30-Minute Batting Practice",
                "Pitching Accuracy Drill – 50 Throws",
                "Fielding Ground Balls – 100 Reps",
                "Sprint Intervals – 10×50m",
                "Weight Training: Squats 3×12",
                "Core Strength: Planks 5×1 min",
                "Agility Ladder Drills – 5 Sets",
                "Catching Pop-Flys – 30 Reps"
            ]
            title = trainingTitles.randomElement()!
        } else {
            let rewardTitles = [
                "Score a Home Run",
                "Get 5 Strikeouts",
                "Make a Diving Catch",
                "Steal a Base",
                "Hit a Double",
                "Pitch a Clean Inning"
            ]
            title = rewardTitles.randomElement()!
        }

        let difficulty = Difficulty.allCases.randomElement() ?? .easy

        let rewardPoints: Int = {
            switch difficulty {
            case .easy:   return 100
            case .medium: return 200
            case .hard:   return 500
            }
        }()

        let cashForThis: Double? = (type == .training) ? nil : nil

        let category: ChallengeCategory = {
            if title.contains("Run") { return .baseRunning }
            if title.contains("Strikeout") || title.contains("Pitch") { return .pitching }
            if title.contains("Catch") { return .catching }
            return .fielding
        }()

        return Challenge(
            id: UUID().uuidString,
            category: category,
            title: title,
            type: type,
            difficulty: difficulty,
            rewardCash: cashForThis,
            rewardPoints: rewardPoints,
            timeRemaining: Double.random(in: 1...3) * 86_400,
            state: .available
        )
    }

    // MARK: — Data loading

    private func loadUserAcceptedChallenges() {
        guard let uid = userID else { return }
        db.collection("users").document(uid).collection("acceptedChallenges")
            .getDocuments { snapshot, _ in
                acceptedChallenges = snapshot?.documents.compactMap { parseChallengeData($0.data()) } ?? []
            }
    }

    private func loadEvents() {
        db.collection("events").getDocuments { snapshot, _ in
            events = snapshot?.documents.compactMap { parseEventDocument($0) } ?? []
            eventsLoaded = true
        }
    }

    // Use this one when reading from a QueryDocumentSnapshot (getDocuments)
    private func parseEventDocument(_ doc: QueryDocumentSnapshot) -> Event? {
        let d = doc.data()
        guard
            let title    = d["title"] as? String,
            let homeTeam = d["homeTeam"] as? String,
            let awayTeam = d["awayTeam"] as? String,
            let ts       = d["startAt"] as? Timestamp
        else { return nil }

        let start = ts.dateValue()
        let endDate = (d["endDate"] as? Timestamp)?.dateValue()
            ?? (Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start)
        let ids = (d["challengeIDs"] as? [String]) ?? []

        return Event(
            id: doc.documentID,
            title: title,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            startAt: start,
            endDate: endDate,
            challengeIDs: ids
        )
    }

    // Overload used elsewhere when you already have a DocumentSnapshot
    private func parseEventDocument(_ doc: DocumentSnapshot) -> Event? {
        let d = doc.data() ?? [:]
        guard
            let title    = d["title"] as? String,
            let homeTeam = d["homeTeam"] as? String,
            let awayTeam = d["awayTeam"] as? String,
            let ts       = d["startAt"] as? Timestamp
        else { return nil }

        let start = ts.dateValue()
        let endDate: Date = (d["endDate"] as? Timestamp)?.dateValue()
            ?? (Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start)
        let ids = (d["challengeIDs"] as? [String]) ?? []

        return Event(
            id: doc.documentID,
            title: title,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            startAt: start,
            endDate: endDate,
            challengeIDs: ids
        )
    }

    // MARK: — Accept logic (no auto-linking)

    private func acceptChallenge(_ challenge: Challenge) {
        guard let cid = challenge.id else { showToast("Missing ID"); return }

        // Toggle off if already accepted
        if let accepted = acceptedChallenges.first(where: { $0.id == cid }) {
            unacceptChallenge(challengeID: cid, eventID: accepted.eventID)
            return
        }

        // Add to banner selection immediately (first selection triggers banner)
        if !pendingAccepted.contains(where: { $0.id == cid }) {
            pendingAccepted.append(challenge)
            if pendingAccepted.count == 1 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showChallengeLink = true
                }
            }
        }

        // Save with no event attached (user will link manually)
        saveAcceptedChallenge(challenge, eventID: nil)

        if challenge.type == .training {
            showToast("Added to your training.")
        }
    }

    private func unacceptChallenge(challengeID cid: String, eventID: String?) {
        guard let uid = userID else { return }

        // Remove from banner selection too
        pendingAccepted.removeAll { $0.id == cid }
        if pendingAccepted.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                showChallengeLink = false
            }
        }

        // Optimistic UI
        acceptedChallenges.removeAll { $0.id == cid }
        if let eidx = events.firstIndex(where: { $0.challengeIDs.contains(cid) }) {
            events[eidx].challengeIDs.removeAll { $0 == cid }
        }

        // Remove from user's accepted list
        db.collection("users").document(uid)
            .collection("acceptedChallenges").document(cid)
            .delete { err in
                if let err = err {
                    showToast("Remove failed: \(err.localizedDescription)")
                } else {
                    showToast("Removed from your challenges.")
                }
            }

        // Detach from event’s challengeIDs array
        if let eid = eventID {
            db.collection("events").document(eid)
                .updateData(["challengeIDs": FieldValue.arrayRemove([cid])]) { _ in }
        }
    }

    // Save to Firestore; eventID optional so training never stores one
    private func saveAcceptedChallenge(_ challenge: Challenge, eventID: String?) {
        guard let uid = userID, let cid = challenge.id else { return }
        var c = challenge; c.eventID = eventID

        var data: [String: Any] = [
            "id": cid,
            "category": c.category.rawValue,
            "title": c.title,
            "type": c.type.rawValue,
            "difficulty": c.difficulty.rawValue,
            "state": c.state.rawValue,
            "acceptedDate": Timestamp(date: Date())
        ]
        if let eid  = eventID { data["eventID"] = eid }
        if c.type == .sponsored, let cash = c.rewardCash { data["rewardCash"] = cash }
        if let pts  = c.rewardPoints { data["rewardPoints"] = pts }
        if let secs = c.timeRemaining { data["timeRemaining"] = secs }
        if let start = c.startAt { data["startAt"] = Timestamp(date: start) }

        db.collection("users").document(uid)
            .collection("acceptedChallenges").document(cid)
            .setData(data) { err in
                if let err = err {
                    showToast("Save failed: \(err.localizedDescription)")
                } else {
                    acceptedChallenges.append(c)
                }
            }
    }

    // MARK: — Parsing helpers

    private func parseChallengeData(_ data: [String: Any]) -> Challenge? {
        guard
            let id      = data["id"] as? String,
            let catRaw  = data["category"] as? String,
            let cat     = ChallengeCategory(rawValue: catRaw),
            let title   = data["title"] as? String,
            let typeRaw = data["type"] as? String,
            let type    = ChallengeType(rawValue: typeRaw),
            let diffRaw = data["difficulty"] as? String,
            let diff    = Difficulty(rawValue: diffRaw),
            let stateRaw = data["state"] as? String,
            let state   = ChallengeState(rawValue: stateRaw)
        else { return nil }

        return Challenge(
            id: id,
            category: cat,
            title: title,
            type: type,
            difficulty: diff,
            rewardCash: data["rewardCash"] as? Double,
            rewardPoints: data["rewardPoints"] as? Int,
            timeRemaining: data["timeRemaining"] as? TimeInterval,
            state: state,
            acceptedDate: (data["acceptedDate"] as? Timestamp)?.dateValue(),
            startAt: (data["startAt"] as? Timestamp)?.dateValue(),
            eventID: data["eventID"] as? String
        )
    }

    // MARK: — Toast

    private func showToast(_ message: String) {
        toastTimer?.invalidate()
        toastMessage = message
        toastTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: — Banner helpers

    private func linkModels() -> [ChallengeLink] {
        pendingAccepted.map { ch in
            let hasCash = (ch.rewardCash ?? 0) > 0 || ch.type == .sponsored
            return ChallengeLink(
                id: ch.id ?? UUID().uuidString,
                imageURL: nil,
                imageName: nil,
                initials: initialsFromTitle(ch.title),
                accentSymbolName: nil,
                isCash: hasCash
            )
        }
    }

    private func initialsFromTitle(_ title: String) -> String {
        let parts = title.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "C"
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    private func eventToShow() -> Event? {
        let cal = Calendar.current
        if let today = events
            .filter({ cal.isDateInToday($0.startAt) })
            .sorted(by: { $0.startAt < $1.startAt })
            .first { return today }
        return events
            .filter({ $0.startAt > Date() })
            .sorted(by: { $0.startAt < $1.startAt })
            .first
    }
}

// Small helper for the empty hero state
private struct ZstackNoScheduled: View {
    var body: some View {
        ZStack {
            Image("UpcomingGame")
                .resizable()
                .scaledToFill()
                .clipped()
            Text("No scheduled events")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .shadow(radius: 4)
        }
    }
}

// Match SponsorHomeView’s tab pill style
// Modern tab style using design system
private extension View {
    func tabStyle(_ selected: Bool) -> some View {
        self
            .modernTab(isSelected: selected)
    }
}

private func currencyString(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    return f.string(from: NSNumber(value: amount)) ?? "$0.00"
}

private struct StatChip: View {
    let icon: String
    let text: String
    var width: CGFloat = 80

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .frame(width: width, height: 26)
        .background(Color.blue)
        .clipShape(Capsule())
    }
}
