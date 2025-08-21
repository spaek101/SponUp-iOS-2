import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SponsorHomeView: View {
    // MARK: — Inject ChaiAgent for fuzzy matching (exists elsewhere)
    @EnvironmentObject private var agent: ChaiAgent

    // MARK: — Firebase
    private let db = Firestore.firestore()
    private var sponsorID: String? { Auth.auth().currentUser?.uid }

    // MARK: — Inputs
    let userFullName: String

    // MARK: — Wallet & Challenges
    @State private var walletBalance: Double = 75.00
    @State private var showFundingCart = false
    @State private var isChatOpen = false

    // Cart (AI suggestions user clicked “Fund” on)
    @State private var fundedChallenges: [Challenge] = []
    @State private var rewardChallenges: [Challenge] = []
    @State private var trainingChallenges: [Challenge] = []

    // Live funded source IDs for rendering “Funded” on cards
    @State private var fundedSourceIDs: Set<String> = []
    private let fundedStates: [String] = ["available", "selected", "inProgress"]  // include "available"
    @State private var fundedListenerRegs: [ListenerRegistration] = []


    // MARK: — Athletes (multi-select)
    @State private var athletes: [Athlete] = []
    @State private var selectedAthleteIDs: Set<String> = []

    // MARK: — Filter
    @State private var selectedFilter: SuggestedFilter = .eventFocus

    // MARK: — Funding preconditions & mapping
    @State private var showSelectAthletesAlert = false
    /// challengeID -> selected athleteIDs snapshot at time of add
    @State private var fundingTargets: [String: Set<String>] = [:]

    // MARK: — UX
    @State private var showFundedToast = false
    @State private var isFunding = false

    // MARK: — Layout
    private let cardHeight: CGFloat = 80

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // ── Top row: Sponsor header (includes balance + Add) ───────────────
                        WelcomeHeader(
                            userFirstName: userFullName.components(separatedBy: " ").first ?? "",
                            userLastName:  userFullName.components(separatedBy: " ").dropFirst().joined(separator: " "),
                            balance:       walletBalance,
                            compact:       true
                        ) {
                            // TODO: present top-up flow
                        }
                        .padding(.horizontal)


                        // ── Instruction Text ──────────────────────────
                        Text("Select the athletes you would like to challenge.")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        // ── Athlete Pills (multi-select) ──────────────────────────
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(athletes) { athlete in
                                    Button {
                                        if selectedAthleteIDs.contains(athlete.id) {
                                            selectedAthleteIDs.remove(athlete.id)
                                        } else {
                                            selectedAthleteIDs.insert(athlete.id)
                                        }
                                    } label: {
                                        Text(athlete.displayName)
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedAthleteIDs.contains(athlete.id)
                                                    ? Color.blue
                                                    : Color(.systemGray5)
                                            )
                                            .foregroundColor(
                                                selectedAthleteIDs.contains(athlete.id)
                                                    ? .white
                                                    : .primary
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // ── Filter Tabs ─────────────────────────────
                        HStack(spacing: 12) {
                            Button("Challenge") { selectedFilter = .eventFocus }
                                .tabStyle(selectedFilter == .eventFocus)

                            Button("Training") { selectedFilter = .training }
                                .tabStyle(selectedFilter == .training)

                            Spacer()
                        }
                        .padding(.horizontal)

                        // Build a fast lookup once per render (Set of funded SOURCE ids)
                        let fundedIDs = fundedSourceIDs

                        // ── Suggested Challenges (Event Focus) ────────────────────
                        if selectedFilter == .eventFocus && !rewardChallenges.isEmpty {
                            SuggestedChallengesSection(
                                challenges: $rewardChallenges,
                                selectedFilter: $selectedFilter,
                                headerType: "rewards",
                                onClaim: toggleFundChallenge,
                                onShowMore: regenerateRewardChallenges
                            ) { challenge, onClaim in
                                AnyView(
                                    ChallengeCardView(
                                        challenge: challenge,
                                        onClaim: onClaim,
                                        fundButton: true, // sponsor context
                                        isFunded: {
                                            guard let srcID = challenge.id else { return false }
                                            return fundedIDs.contains(srcID)  // from backend listener (sourceChallengeID set)
                                        }(),
                                        isSelected: fundedChallenges.contains { $0.id == challenge.id } // cart selection
                                    )
                                )
                            }
                            .padding(.horizontal)
                        }

                        // ── Suggested Challenges (Training) ───────────────────────
                        if selectedFilter == .training && !trainingChallenges.isEmpty {
                            SuggestedChallengesSection(
                                challenges: $trainingChallenges,
                                selectedFilter: $selectedFilter,
                                headerType: "training",
                                onClaim: toggleFundChallenge,
                                onShowMore: regenerateTrainingChallenges
                            ) { challenge, onClaim in
                                AnyView(
                                    ChallengeCardView(
                                        challenge: challenge,
                                        onClaim: onClaim,
                                        fundButton: true,
                                        isFunded: {
                                            guard let srcID = challenge.id else { return false }
                                            return fundedIDs.contains(srcID)
                                        }(),
                                        isSelected: fundedChallenges.contains { $0.id == challenge.id }
                                    )
                                )
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // ── Floating Cart Button ──────────────────────
                if !fundedChallenges.isEmpty {
                    Button { showFundingCart = true } label: {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 24))
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding()
                    .accessibilityLabel("Open Funding Cart")
                }

                // ── Chat Panel Overlay ───────────────────────
                if isChatOpen {
                    ChaiChatView(isOpen: $isChatOpen)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(1)
                }

                // ── Toast Overlay ───────────────────────────────
                if showFundedToast {
                    VStack {
                        Spacer()
                        ToastBanner(text: "Successfully funded!")
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.25), value: showFundedToast)
                }
            }

            // ── Cart Sheet ─────────────────────────────────────
            .sheet(isPresented: $showFundingCart) {
                FundingCartView(
                    fundedChallenges: $fundedChallenges,
                    walletBalance: $walletBalance,
                    fundingTargets: $fundingTargets,
                    nameForAthleteID: { id in
                        athletes.first(where: { $0.id == id })?.displayName ?? "" },
                    onConfirmFunding: {
                        payForChallenges()
                        showFundingCart = false
                    },
                    onTopUp: { /*…*/ }
                )
            }

            // ── Alerts ─────────────────────────────────────────
            .alert("Select at least one athlete", isPresented: $showSelectAthletesAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Pick who you want to fund first, then choose challenges.")
            }


            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .onAppear {
                loadConnectedAthletes()
                loadRewardChallenges()
                loadTrainingChallenges()
                startFundedListeners()
            }
            .onChange(of: selectedAthleteIDs) { _ in
                startFundedListeners()
            }
        }
    }

    // MARK: — Load connected athletes
    private func loadConnectedAthletes() {
        guard let sponsor = sponsorID else { return }
        db.collection("users")
            .document(sponsor)
            .collection("connectedAthletes")
            .getDocuments { snap, _ in
                let fetched = snap?.documents.compactMap { doc -> Athlete? in
                    let data = doc.data()
                    return Athlete(
                        id: doc.documentID,
                        displayName: data["fullName"] as? String ?? "No Name"
                    )
                } ?? []
                athletes = fetched.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                agent.knownAthletes = athletes.map { $0.displayName }
            }
    }

    // MARK: — Challenge helpers (cart add/remove only)
    private func toggleFundChallenge(_ c: Challenge) {
        if let idx = fundedChallenges.firstIndex(where: { $0.id == c.id }) {
            fundedChallenges.remove(at: idx)
            if let id = c.id { fundingTargets[id] = nil }
        } else {
            guard !selectedAthleteIDs.isEmpty else {
                showSelectAthletesAlert = true
                return
            }
            fundedChallenges.append(c)
            if let id = c.id { fundingTargets[id] = selectedAthleteIDs }
        }
    }

    // MARK: — Cash by difficulty
    private func cashValue(for c: Challenge) -> Double {
        switch c.difficulty {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 20
        }
    }

    // MARK: — Commit funding to Firestore (fan-out per athlete)
    private func payForChallenges() {
        guard let sponsor = sponsorID else { return }
        guard !fundedChallenges.isEmpty else { return }

        isFunding = true
        let batch = db.batch()
        var totalCash: Double = 0

        for ch in fundedChallenges {
            guard let cid = ch.id, let targets = fundingTargets[cid], !targets.isEmpty else { continue }
            let cash = cashValue(for: ch)
            totalCash += cash * Double(targets.count)

            for athleteID in targets {
                let base = db.collection("users").document(athleteID)

                // users/{athleteID}/challenges/{autoId}
                let challengeDoc = base.collection("challenges").document()

                let challengeData: [String: Any] = [
                    "id": challengeDoc.documentID,
                    "title": ch.title,
                    "category": ch.category.rawValue,
                    "type": ChallengeType.sponsored.rawValue,
                    "difficulty": ch.difficulty.rawValue,

                    // publish to athlete feed as available
                    "state": ChallengeState.available.rawValue,  // ✅ NOW AVAILABLE

                    "rewardCash": cash,
                    "rewardPoints": ch.rewardPoints ?? 0,
                    "imageName": ch.imageName,
                    "imageURL": ch.imageURL as Any? ?? NSNull(),
                    "timeRemaining": ch.timeRemaining as Any? ?? NSNull(),
                    "sponsorID": sponsor,
                    "sponsorName": userFullName,
                    "athleteID": athleteID,
                    "sourceChallengeID": cid,
                    "createdAt": FieldValue.serverTimestamp(),
                    "fundedAt": FieldValue.serverTimestamp()
                ]


                batch.setData(challengeData, forDocument: challengeDoc)

                // Optional mirror collection
                let sponsoredDoc = base.collection("sponsoredChallenges").document()
                var altData = challengeData
                altData["id"] = sponsoredDoc.documentID
                batch.setData(altData, forDocument: sponsoredDoc)
            }
        }

        batch.commit { err in
            isFunding = false
            if let err = err {
                print("Funding batch error: \(err)")
                return
            }

            // Deduct from wallet (simple local sim)
            walletBalance = max(0, walletBalance - totalCash)

            // 🔥 REMOVE funded cards from the on-screen lists
            DispatchQueue.main.async {
                let justFundedIDs = Set(fundedChallenges.compactMap { $0.id })
                rewardChallenges.removeAll { ch in
                    if let id = ch.id { return justFundedIDs.contains(id) }
                    return false
                }
                trainingChallenges.removeAll { ch in
                    if let id = ch.id { return justFundedIDs.contains(id) }
                    return false
                }
            }

            // Clear cart + selections
            fundedChallenges.removeAll()
            fundingTargets.removeAll()

            // Success toast
            showFundedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { showFundedToast = false }
            }
        }
    }

    // MARK: — Real-time funded listeners (collect sourceChallengeIDs)
    private func startFundedListeners() {
        // Remove old listeners
        for reg in fundedListenerRegs { reg.remove() }
        fundedListenerRegs.removeAll()
        fundedSourceIDs.removeAll()

        // Watch selected athletes; if none selected, watch all connected
        let idsToWatch: Set<String> =
            selectedAthleteIDs.isEmpty ? Set(athletes.map { $0.id }) : selectedAthleteIDs
        guard !idsToWatch.isEmpty else { return }

        for athleteID in idsToWatch {
            let q = db.collection("users")
                .document(athleteID)
                .collection("challenges")
                .whereField("type", isEqualTo: "sponsored")
                .whereField("state", in: fundedStates)

            let reg = q.addSnapshotListener { snap, err in
                if let err = err {
                    print("funded listener error (\(athleteID)):", err.localizedDescription)
                    return
                }

                // Merge all sourceChallengeIDs that are funded/selected
                var union = fundedSourceIDs
                for d in snap?.documents ?? [] {
                    if let src = d.get("sourceChallengeID") as? String {
                        union.insert(src)
                    }
                }
                fundedSourceIDs = union

                // 🔥 Remove any now-funded items from the suggestions on screen
                DispatchQueue.main.async {
                    rewardChallenges.removeAll { ch in
                        guard let id = ch.id else { return false }
                        return union.contains(id)
                    }
                    trainingChallenges.removeAll { ch in
                        guard let id = ch.id else { return false }
                        return union.contains(id)
                    }
                }
            }

            fundedListenerRegs.append(reg)
        }
    }

    // MARK: — AI challenge generation (local)
    private func loadRewardChallenges() {
        rewardChallenges = (0..<8).map { _ in generateSingleAIChallenge(type: .reward) }
    }
    private func regenerateRewardChallenges() { loadRewardChallenges() }

    private func loadTrainingChallenges() {
        trainingChallenges = (0..<8).map { _ in generateSingleAIChallenge(type: .training) }
    }
    private func regenerateTrainingChallenges() { loadTrainingChallenges() }

    private func generateSingleAIChallenge(type: ChallengeType) -> Challenge {
        // 1) Title by type
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

        // 2) Random difficulty
        let difficulty = Difficulty.allCases.randomElement() ?? .easy

        // 3) Cash/points
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

        // 4) Category for image
        let category: ChallengeCategory = {
            if title.contains("Run") { return .baseRunning }
            if title.contains("Strikeout") || title.contains("Pitch") { return .pitching }
            if title.contains("Catch") { return .catching }
            return .fielding
        }()

        // 5) Build
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
}

// MARK: — Athlete Model (light)
struct Athlete: Identifiable {
    let id: String
    let displayName: String
}

// MARK: — Toast
private struct ToastBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.95))
            .cornerRadius(14)
            .shadow(radius: 4)
            .padding(.bottom, 24)
    }
}

// MARK: — Tab-style helper
private extension View {
    func tabStyle(_ selected: Bool) -> some View {
        self
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Color.blue : Color.blue.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(16)
    }
}
