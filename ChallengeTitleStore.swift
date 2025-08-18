//
//  ChallengeTitleStore.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/7/25.
//


import FirebaseFirestore
import Combine

class ChallengeTitleStore: ObservableObject {
    @Published var gameTitles: [String] = []
    @Published var trainingTitles: [String] = []
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        subscribe(to: "game",       publisher: $gameTitles)
        subscribe(to: "training",  publisher: $trainingTitles)
    }
    
    private func subscribe(to docID: String, publisher: Published<[String]>.Publisher) {
        let ref = db.collection("challengeTitles").document(docID)
        // Listen for remote updates
        ref.addSnapshotListener { [weak self] snap, err in
            guard let data = snap?.data(),
                  let list = data["titles"] as? [String] else { return }
            DispatchQueue.main.async {
                if docID == "game" {
                    self?.gameTitles = list
                } else {
                    self?.trainingTitles = list
                }
            }
        }
    }
    
    func save(_ titles: [String], for docID: String) {
        db.collection("challengeTitles").document(docID)
            .setData(["titles": titles], merge: true)
    }
}
