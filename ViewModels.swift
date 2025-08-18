import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Leaderboard (non-live; fetch on demand)
@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var topThree: [LeaderboardEntry] = []

    private let db = Firestore.firestore()
    private var isLoading = false

    /// Async version used by `.refreshable {}` and `.task {}`.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snap = try await db.collection("users")
                .order(by: "pointsTotal", descending: true)
                .limit(to: 100)
                .getDocuments()

            let me = Auth.auth().currentUser?.uid

            let mapped: [LeaderboardEntry] = snap.documents.map { doc in
                let d = doc.data()
                let name = (d["fullName"] as? String)
                       ?? (d["displayName"] as? String)
                       ?? (d["name"] as? String)
                       ?? "Player"
                let pts  = d["pointsTotal"] as? Int ?? 0
                return LeaderboardEntry(
                    id: doc.documentID,
                    name: name,
                    points: pts,
                    rank: nil,
                    avatarURL: (d["avatarURL"] as? String) ?? (d["photoURL"] as? String),
                    isYou: doc.documentID == me
                )
            }

            // points DESC, then name ASC, then id ASC (stable for exact ties)
            let ordered = mapped.sorted {
                if $0.points != $1.points { return $0.points > $1.points }
                let cmp = $0.name.localizedCaseInsensitiveCompare($1.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return $0.id < $1.id
            }

            // assign 1-based ranks
            let ranked = ordered.enumerated().map { idx, e -> LeaderboardEntry in
                var x = e; x.rank = idx + 1; return x
            }

            self.entries  = ranked
            self.topThree = Array(ranked.prefix(3))
        } catch {
            print("leaderboard refresh error:", error)
        }
    }

    /// Back-compat shim so existing call sites that aren’t async still work.
    func refresh() {
        Task { await refresh() }
    }
}


// MARK: - Tier (Points progress)
final class TierViewModel: ObservableObject {
    @Published var points: Int = 0
    @Published var nextSkinTarget: Int = 1000

    private let db = Firestore.firestore()
    private var pointsListener: ListenerRegistration?

    deinit { stopListening() }

    func startListening(uid: String) {
        stopListening()
        let ref = db.collection("users").document(uid)
            .collection("totals").document("points")

        pointsListener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                print("Points listener error:", error)
                return
            }
            let total = (snap?.data()?["total"] as? Int) ?? 0
            DispatchQueue.main.async {
                self.points = total
                self.nextSkinTarget = Self.computeTarget(for: total)
            }
        }
    }

    func stopListening() {
        pointsListener?.remove()
        pointsListener = nil
    }

    private static func computeTarget(for points: Int, step: Int = 1000) -> Int {
        guard points >= 0 else { return step }
        let nextBucket = ((points / step) + 1) * step
        return max(nextBucket, step)
    }

    // Atomic dual-write so totals AND root pointsTotal stay in sync.
    func addPoints(_ pts: Int) {
        guard pts != 0, let uid = Auth.auth().currentUser?.uid else { return }

        let userRef   = db.collection("users").document(uid)
        let pointsRef = userRef.collection("totals").document("points")
        let batch = db.batch()

        batch.setData(["total": FieldValue.increment(Int64(pts))],
                      forDocument: pointsRef, merge: true)

        batch.setData(["pointsTotal": FieldValue.increment(Int64(pts))],
                      forDocument: userRef, merge: true)

        batch.commit { err in
            if let err = err {
                print("addPoints batch error:", err.localizedDescription)
            }
        }
    }

    func addCashCents(_ cents: Int) {
        guard cents != 0, let uid = Auth.auth().currentUser?.uid else { return }

        let userRef = db.collection("users").document(uid)
        let cashRef = userRef.collection("totals").document("cash")
        let batch = db.batch()

        batch.setData([
            "totalCents": FieldValue.increment(Int64(cents)),
            "currency": "USD"
        ], forDocument: cashRef, merge: true)

        // Optional: mirror cash at root if you plan to query by it
        // batch.setData(["cashTotalCents": FieldValue.increment(Int64(cents))],
        //               forDocument: userRef, merge: true)

        batch.commit { err in
            if let err = err {
                print("addCashCents batch error:", err.localizedDescription)
            }
        }
    }
}

// MARK: - Cart
final class CartViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    var isVisible: Bool { !challenges.isEmpty }

    func add(_ challenge: Challenge) {
        guard !challenges.contains(where: { $0.id == challenge.id }) else { return }
        challenges.append(challenge)
    }
}

// MARK: - Event (today)
final class EventViewModel: ObservableObject {
    @Published var todayEvent: Event? = nil
    private let db = Firestore.firestore()

    init() { fetchTodayEvent() }

    func fetchTodayEvent() {
        let start = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        db.collection("events")
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("startAt", isLessThan: Timestamp(date: end))
            .order(by: "startAt")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to fetch today's event:", error)
                    return
                }
                guard let doc = snapshot?.documents.first else {
                    DispatchQueue.main.async { self.todayEvent = nil }
                    return
                }
                let event = Event(from: doc)
                DispatchQueue.main.async { self.todayEvent = event }
            }
    }
}

// MARK: - Event convenience mapper (uses endDate only)
extension Event {
    init(from doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]

        let id = doc.documentID
        let title = d["title"] as? String ?? ""
        let homeTeam = d["homeTeam"] as? String ?? ""
        let awayTeam = d["awayTeam"] as? String ?? ""
        let start = (d["startAt"] as? Timestamp)?.dateValue() ?? Date()
        let endDate = (d["endDate"] as? Timestamp)?.dateValue()
            ?? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start
        let challengeIDs = d["challengeIDs"] as? [String] ?? []

        self.init(
            id: id,
            title: title,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            startAt: start,
            endDate: endDate,
            challengeIDs: challengeIDs
        )
    }
}
