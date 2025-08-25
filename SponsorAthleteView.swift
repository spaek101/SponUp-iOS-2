import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UIKit

// MARK: - Linked Athlete Model

/// Represents an athlete linked to the sponsor
struct LinkedAthlete: Identifiable, Equatable {
    let id: String
    let fullName: String
    let totalFunded: Double
    let avatarName: String?  // Optional asset name for local images
}

// MARK: - SponsorAthleteView

struct SponsorAthleteView: View {
    // MARK: State & Properties

    @State private var newAthleteID: String = ""
    @State private var searchText: String = ""
    @State private var linkedAthletes: [LinkedAthlete] = []
    @State private var showAddAthleteAlert = false
    @State private var addAthleteMessage = ""
    @State private var athleteToUnlink: LinkedAthlete? = nil
    @State private var showUnlinkConfirmation = false

    private let db = Firestore.firestore()
    private var sponsorID: String? { Auth.auth().currentUser?.uid }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // ── Link a New Athlete ─────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Link a new athlete")
                        .font(.headline)

                    HStack(spacing: 0) {
                        Button(action: { /* TODO: scan QR code */ }) {
                            Label("Scan QR", systemImage: "qrcode")
                                .frame(maxWidth: .infinity)
                        }
                        Divider()
                        TextField("Enter athlete ID", text: $newAthleteID)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                        Divider()
                        Button("Link") {
                            addAthlete(byID: newAthleteID)
                        }
                        .disabled(newAthleteID.trimmingCharacters(in: .whitespaces).isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                // ── Search Bar ─────────────────────────────────
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search athletes", text: $searchText)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // ── Header ────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linked Athletes (A–Z)")
                        .font(.headline)
                    Text("Swipe left on an athlete to unlink")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // ── Athletes List ─────────────────────────────
                List {
                    ForEach(filteredAthletes()) { athlete in
                        HStack(spacing: 12) {
                            // Avatar or initials
                            if let imgName = athlete.avatarName,
                               !imgName.isEmpty,
                               UIImage(named: imgName) != nil {
                                Image(imgName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                let initials = athlete.fullName
                                    .split(separator: " ")
                                    .compactMap { $0.first }
                                    .map(String.init)
                                    .joined()
                                Text(initials)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.purple)
                                    .clipShape(Circle())
                            }

                            // Name
                            Text(athlete.fullName)
                                .font(.body)

                            Spacer()

                            // Total funded
                            Text("$\(Int(athlete.totalFunded))")
                                .font(.body)
                        }
                        .padding(.vertical, 8)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                athleteToUnlink = athlete
                                showUnlinkConfirmation = true
                            } label: {
                                Label("Unlink", systemImage: "person.crop.circle.badge.minus")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Athletes")
            .onAppear(perform: loadConnectedAthletes)
            // MARK: Alerts
            .alert(addAthleteMessage, isPresented: $showAddAthleteAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Unlink Athlete",
                   isPresented: $showUnlinkConfirmation,
                   presenting: athleteToUnlink) { athlete in
                Button("Unlink", role: .destructive) {
                    removeAthlete(athlete)
                }
                Button("Cancel", role: .cancel) { }
            } message: { athlete in
                Text("Are you sure you want to unlink \(athlete.fullName)?")
            }
        }
    }

    // MARK: - Filtering

    private func filteredAthletes() -> [LinkedAthlete] {
        let sorted = linkedAthletes.sorted { $0.fullName < $1.fullName }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Firestore Operations

    private func loadConnectedAthletes() {
        guard let sponsor = sponsorID else { return }
        db.collection("users")
            .document(sponsor)
            .collection("connectedAthletes")
            .getDocuments { snap, err in
                if let err = err {
                    print("Load failed: \(err.localizedDescription)")
                    return
                }
                let docs = snap?.documents ?? []
                let athletes = docs.compactMap { d -> LinkedAthlete? in
                    let data = d.data()
                    guard let id = data["id"] as? String,
                          let name = data["fullName"] as? String,
                          let funded = data["totalFunded"] as? Double else {
                        return nil
                    }
                    let avatar = data["avatarName"] as? String
                    return LinkedAthlete(
                        id: id,
                        fullName: name,
                        totalFunded: funded,
                        avatarName: avatar
                    )
                }
                DispatchQueue.main.async {
                    linkedAthletes = athletes
                }
            }
    }

    private func addAthlete(byID id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        // Prevent duplicates
        if linkedAthletes.contains(where: { $0.id == trimmed }) {
            showError("Athlete is already linked.")
            return
        }
        guard let sponsor = sponsorID else { return }

        // Verify athlete exists and is role == "athlete"
        db.collection("users").document(trimmed).getDocument { snap, err in
            if let err = err {
                showError("Fetch failed: \(err.localizedDescription)")
                return
            }
            guard
                let data = snap?.data(),
                let name = data["fullName"] as? String,
                let role = data["role"] as? String,
                role.lowercased() == "athlete"
            else {
                showError("No athlete found with that ID.")
                return
            }
            let record: [String:Any] = [
                "id":          trimmed,
                "fullName":    name,
                "totalFunded": 0.0,
                "avatarName":  data["avatarName"] as? String ?? ""
            ]
            db.collection("users")
                .document(sponsor)
                .collection("connectedAthletes")
                .document(trimmed)
                .setData(record) { e in
                    if let e = e {
                        showError("Add failed: \(e.localizedDescription)")
                    } else {
                        showError("Athlete added: \(name)")
                        loadConnectedAthletes()
                        newAthleteID = ""
                    }
                }
        }
    }

    private func removeAthlete(_ athlete: LinkedAthlete) {
        guard let sponsor = sponsorID else { return }
        db.collection("users")
            .document(sponsor)
            .collection("connectedAthletes")
            .document(athlete.id)
            .delete { err in
                if let err = err {
                    print("Remove failed: \(err.localizedDescription)")
                } else {
                    loadConnectedAthletes()
                }
            }
    }

    private func showError(_ msg: String) {
        addAthleteMessage = msg
        showAddAthleteAlert = true
    }
}

