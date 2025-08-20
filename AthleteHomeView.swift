import SwiftUI
import FirebaseFirestore
import FirebaseAuth

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

    // Banner state
    @State private var pendingAccepted: [Challenge] = []
    @State private var showChallengeLink = false

    // Present details as a sheet (prevents frozen UI)
    @State private var navigateToLinkDetails = false

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        let userFirstName = userFullName.components(separatedBy: " ").first ?? ""
                        let userLastName = userFullName.components(separatedBy: " ").dropFirst().joined(separator: " ")

                        WelcomeHeader(
                            userFirstName: userFirstName,
                            userLastName: userLastName,
                            points: tierVM.points,
                            cash: Int(acceptedChallenges.compactMap { $0.rewardCash }.reduce(0, +))
                        )
                        .padding(.top, 0)

                        // Header area: loading → hero → empty-state
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

                                if !listToShow.isEmpty {
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
                                } else {
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
                                    .frame(height: heroHeaderHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                }
                            }
                        }

                        // Push content below header
                        Color.clear.frame(height: 12)

                        // Tabs row
                        VStack(spacing: 12) {
                            NavigationLink {
                                LeaderboardView().environmentObject(leaderboardVM)
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("View Leaderboard")
                                        .font(.footnote.bold())
                                        .foregroundColor(.black)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)

                            HStack(spacing: 12) {
                                Button("Challenge") { selectedFilter = .eventFocus }
                                    .tabStyle(selectedFilter == .eventFocus)
                                Button("Training") { selectedFilter = .training }
                                    .tabStyle(selectedFilter == .training)
                                Button("Sponsored") { selectedFilter = .sponsored }
                                    .tabStyle(selectedFilter == .sponsored)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)

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
                                            isFunded: acceptedChallenges.contains { $0.id == challenge.id }
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
                                        isFunded: acceptedChallenges.contains { $0.id == challenge.id }
                                    )
                                )
                            }
                            .padding(.horizontal)
                        } else if selectedFilter == .sponsored {
                            // Live Firestore-backed sponsored challenges
                            SponsoredTab(
                                challenges: $sponsoredVM.sponsored,
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
            // Keep background, no navigation title
            .background(
                Image("leaderboard_bg")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.15)
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

                // Start listening for sponsored challenges
                if let uid = Auth.auth().currentUser?.uid {
                    sponsoredVM.start(for: uid)
                }
            }
            .onDisappear {
                sponsoredVM.stop()
            }
            // Bottom banner appears as soon as first challenge is selected
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showChallengeLink && !pendingAccepted.isEmpty {
                    ChallengeLinkBanner(
                        avatars: linkModels(),                // [ChallengeLink]
                        headline: "Link",
                        subheadline: "Tap to review",
                        maxVisibleAvatars: 6,
                        onPrimaryTap: {
                            // Hide banner, then open sheet
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
                        showChallengeLink = false
                        navigateToLinkDetails = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                } else {
                    Color.clear.frame(height: 0)
                }
            }
            // Present details as a SHEET (avoids overlay freezes)
            .sheet(isPresented: $navigateToLinkDetails, onDismiss: {
                // If picks still exist, you can show the banner again
                showChallengeLink = !pendingAccepted.isEmpty
            }) {
                ChallengeLinkDetails(
                    selectedChallenges: $pendingAccepted,
                    targetEventTitle: eventToShow()?.title,
                    onConfirmLink: {
                        // Commit your link action here if needed
                        navigateToLinkDetails = false
                        showChallengeLink = false
                    },
                    onClear: {
                        withAnimation { pendingAccepted.removeAll() }
                        navigateToLinkDetails = false
                        showChallengeLink = false
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

        let rewardCash: Double? = {
            switch difficulty {
            case .easy:   return type == .reward ? 5  : nil
            case .medium: return type == .reward ? 10 : nil
            case .hard:   return type == .reward ? 20 : nil
            }
        }()

        let rewardPoints: Int = {
            switch difficulty {
            case .easy:   return 100
            case .medium: return 200
            case .hard:   return 500
            }
        }()

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
            rewardCash: rewardCash,
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

    // MARK: — Accept logic
    private func acceptChallenge(_ challenge: Challenge) {
        guard let cid = challenge.id else { showToast("Missing ID"); return }

        // Toggle: if already accepted → remove it
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

        // TRAINING: never attach to an event
        if challenge.type == .training {
            saveAcceptedChallenge(challenge, eventID: nil)
            showToast("Added to your training.")
            return
        }

        // GAME (reward/sponsored): attach to earliest upcoming event
        let candidates = events
            .filter { $0.startAt >= Date() }
            .sorted { $0.startAt < $1.startAt }

        guard !candidates.isEmpty else {
            cartVM.add(challenge)
            showToast("No upcoming event available")
            return
        }

        var chosenEventID: String?

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            for ev in candidates {
                guard let eid = ev.id else { continue }
                let ref = db.collection("events").document(eid)

                let snap: DocumentSnapshot
                do { snap = try transaction.getDocument(ref) }
                catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                var ids = (snap.get("challengeIDs") as? [String]) ?? []

                if ids.contains(cid) { chosenEventID = eid; break }

                // capacity check: max 3 challenges/event
                if ids.count < 3 {
                    ids.append(cid)
                    transaction.updateData(["challengeIDs": ids], forDocument: ref)
                    chosenEventID = eid
                    break
                }
            }

            if chosenEventID == nil {
                errorPointer?.pointee = NSError(
                    domain: "AcceptChallenge",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No upcoming event available"]
                )
            }
            return chosenEventID as Any?
        }) { result, error in
            if let eid = result as? String {
                if let idx = events.firstIndex(where: { $0.id == eid }) {
                    if !events[idx].challengeIDs.contains(cid) {
                        events[idx].challengeIDs.append(cid)
                    }
                    showToast("Challenge applied to \(events[idx].title).")
                } else {
                    showToast("Challenge applied.")
                }
                saveAcceptedChallenge(challenge, eventID: eid)
            } else {
                cartVM.add(challenge)
                showToast(error?.localizedDescription ?? "No upcoming event available")
            }
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
        if let cash = c.rewardCash { data["rewardCash"] = cash }
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
            let id = data["id"] as? String,
            let catRaw = data["category"] as? String,
            let cat = ChallengeCategory(rawValue: catRaw),
            let title = data["title"] as? String,
            let typeRaw = data["type"] as? String,
            let type = ChallengeType(rawValue: typeRaw),
            let diffRaw = data["difficulty"] as? String,
            let diff = Difficulty(rawValue: diffRaw),
            let stateRaw = data["state"] as? String,
            let state = ChallengeState(rawValue: stateRaw)
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

    private func parseEventDocument(_ doc: DocumentSnapshot) -> Event? {
        let d = doc.data() ?? [:]
        guard
            let title = d["title"] as? String,
            let homeTeam = d["homeTeam"] as? String,
            let awayTeam = d["awayTeam"] as? String,
            let ts = d["startAt"] as? Timestamp
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

    // MARK: — Toast

    private func showToast(_ message: String) {
        toastTimer?.invalidate()
        toastMessage = message
        toastTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: — Banner helpers (maps pendingAccepted → [ChallengeLink])

    private func linkModels() -> [ChallengeLink] {
        pendingAccepted.map { ch in
            let (url, asset) = challengeBackground(for: ch)
            return ChallengeLink(
                id: ch.id ?? UUID().uuidString,
                imageURL: url,
                imageName: asset,
                initials: initialsFromTitle(ch.title),
                accentSymbolName: "bolt.fill"
            )
        }
    }

    /// Default to a bundled asset; fallback is initials bubble
    private func challengeBackground(for challenge: Challenge) -> (URL?, String?) {
        return (nil, "challenge_default")
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
            .first {
            return today
        }
        return events
            .filter({ $0.startAt > Date() })
            .sorted(by: { $0.startAt < $1.startAt })
            .first
    }
}

// Match SponsorHomeView’s tab pill style
private extension View {
    func tabStyle(_ selected: Bool) -> some View {
        self
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Color.brown : Color(red: 0.93, green: 0.87, blue: 0.74))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
