import Foundation
import FirebaseFirestore

@MainActor
final class SponsoredChallengesViewModel: ObservableObject {
    @Published var sponsored: [Challenge] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func start(for athleteID: String, useAltCollection: Bool = false) {
        listener?.remove()

        var col = db.collection("users")
            .document(athleteID)
            .collection("challenges")
        if useAltCollection {
            col = db.collection("users")
                .document(athleteID)
                .collection("sponsoredChallenges")
        }

        // Strict query (fast, but needs a composite index)
        let strictQ = col
            .whereField("type", isEqualTo: "sponsored")
            .whereField("state", in: ["selected", "inProgress"])
            .order(by: "fundedAt", descending: true) // use createdAt if you prefer

        print("▶️ SponsoredVM.start athleteID=\(athleteID) useAlt=\(useAltCollection)")
        listener = strictQ.addSnapshotListener { [weak self] snap, err in
            // Index missing? Fall back to simple query so UI still works now.
            if let ns = err as NSError?,
               ns.domain == FirestoreErrorDomain,
               ns.code == FirestoreErrorCode.failedPrecondition.rawValue,
               ns.localizedDescription.lowercased().contains("index") {
                print("⚠️ Missing composite index — falling back to simple query (client filter/sort).")
                self?.attachFallbackListener(col: col)
                return
            }

            if let err = err {
                print("❌ sponsored listener error:", err.localizedDescription)
                return
            }
            self?.applySnapshot(snap)
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Fallback: type == sponsored only; filter/sort client-side
    private func attachFallbackListener(col: CollectionReference) {
        listener?.remove()
        let q = col.whereField("type", isEqualTo: "sponsored")
        listener = q.addSnapshotListener { [weak self] snap, err in
            if let err = err {
                print("❌ fallback listener error:", err.localizedDescription)
                return
            }
            guard let self, let snap = snap else { return }
            var items = snap.documents.map { Challenge(from: $0) }

            // Keep only funded states (selected / inProgress)
            items = items.filter { ch in
                ch.state == .selected || ch.state == .inProgress
            }

            // Sort newest first (prefer fundedAt if you add it to your model; else createdAt)
            items.sort { a, b in
                let aDate = a.createdAt ?? .distantPast
                let bDate = b.createdAt ?? .distantPast
                return aDate > bDate
            }

            print("✅ fallback snapshot count=\(items.count)")
            self.sponsored = items
        }
    }

    private func applySnapshot(_ snap: QuerySnapshot?) {
        guard let snap = snap else {
            print("⚠️ sponsored listener: nil snapshot")
            self.sponsored = []
            return
        }
        print("✅ sponsored snapshot count=\(snap.documents.count)")
        self.sponsored = snap.documents.map { Challenge(from: $0) }
    }
}
