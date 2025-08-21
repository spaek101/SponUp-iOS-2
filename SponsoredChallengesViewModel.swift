import Foundation
import FirebaseFirestore

@MainActor
final class SponsoredChallengesViewModel: ObservableObject {
    @Published var sponsored: [Challenge] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    /// Call onAppear with the current athlete's ID.
    /// Feeds should come from a *sponsored feed* collection, not the user's accepted list.
    func start(for athleteID: String, useAltCollection: Bool = false) {
        listener?.remove()

        // Choose feed path
        var col = db.collection("users")
            .document(athleteID)
            .collection("challenges")
        if useAltCollection {
            col = db.collection("users")
                .document(athleteID)
                .collection("sponsoredChallenges")
        }

        // Only show AVAILABLE sponsored items
        let strictQ = col
            .whereField("type", isEqualTo: "sponsored")
            .whereField("state", isEqualTo: "available")
            .order(by: "createdAt", descending: true)  // use "fundedAt" if you prefer

        listener = strictQ.addSnapshotListener { [weak self] snap, err in
            // Missing composite index? Fall back to a simpler query.
            if let ns = err as NSError?,
               ns.domain == FirestoreErrorDomain,
               ns.code == FirestoreErrorCode.failedPrecondition.rawValue,
               ns.localizedDescription.lowercased().contains("index") {
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

    /// Call onDisappear.
    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Fallback listener (no composite index)
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

            // Keep only AVAILABLE items client-side
            items = items.filter { $0.state == .available }
            items.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }

            self.sponsored = items
        }
    }

    // MARK: - Apply snapshot
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
