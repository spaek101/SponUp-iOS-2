import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

// MARK: - Models
struct Sponsor: Identifiable {
    let id: String  // user ID
    let fullName: String
}

// MARK: - View
struct ProfileView: View {
    // Backend state
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var dateOfBirth: Date?
    @State private var role: String = ""
    @State private var userID: String = ""

    // Points
    @State private var totalPoints: Int = 0

    // Sponsors
    @State private var sponsors: [Sponsor] = []
    @State private var sponsorsExpanded = false
    @State private var newSponsorID: String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    // UI
    @State private var showCopyAlert = false
    @State private var isPublicProfile = true
    @State private var showQRSheet = false
    @State private var profilePhotoURL: URL? = nil

    private let db  = Firestore.firestore()
    private let user = Auth.auth().currentUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── HERO HEADER CARD ───────────────────────────────
                    ProfileHeaderCard(
                        fullName: displayName,
                        subtitleTop: "#12 • Eagles • SS",
                        subtitleBottom: "Class of 2027",
                        points: totalPoints,
                        onEdit: { /* push your edit profile view here */ }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // ── SEASON STATS ──────────────────────────────────
                    SectionHeader(title: "Season Stats", trailing: {
                        Button("View All Stats ›") {}
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.indigo)
                    })
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: [.init(.flexible(), spacing: 12),
                                        .init(.flexible(), spacing: 12)],
                              spacing: 12) {
                        StatCard(primary: ".329", title: "Batting", progress: 0.62)
                        StatCard(primary: "8", title: "HR", progress: 0.4)
                        StatCard(primary: "88%", title: "Strikeouts\nThrown", progress: 0.88)
                        StatCard(primary: "$700", title: "RarTrack\nOn Track", progress: 0.7, compact: true)
                        StatCard(primary: "20", title: "Needs 60\nChallengeAccuracy", progress: 0.33, compact: true)
                    }
                    .padding(.horizontal, 16)

                    // ── MY GOALS ──────────────────────────────────────
                    SectionHeader(title: "My Goals", trailing: {
                        Button("Add Sponsor") { sponsorsExpanded = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.indigo)
                    })
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        GoalProgressCard(
                            title: "Complete",
                            subtitle: "10 challenges",
                            current: 7, total: 10,
                            footerLeft: "7/no",
                            footerRight: "$240 00"
                        )

                        HStack(spacing: 12) {
                            IconValuePill(system: "flame.fill", title: "5-Day", subtitle: "Streak")
                            IconValuePill(system: "dollarsign.circle.fill", title: "$500", subtitle: "Raised")
                            IconValuePill(system: "lock.fill", title: "200", subtitle: "pts")
                        }
                    }
                    .padding(.horizontal, 16)

                    // ── UNLOCKED SKINS & BADGES ───────────────────────
                    SectionHeader(title: "Unlocked Skins & Badges", trailing: {
                        Text("Redeem Points*")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    })
                    .padding(.horizontal, 16)

                    // Placeholder strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<8) { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 84, height: 84)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── QR & PUBLIC PROFILE TOGGLE ROWS ───────────────
                    VStack(spacing: 12) {
                        RowCard {
                            Button {
                                showQRSheet = true
                            } label: {
                                HStack {
                                    Text("QR Code")
                                    Spacer()
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .sheet(isPresented: $showQRSheet) {
                            QRCodeSheet(userID: userID)
                        }

                        RowCard {
                            HStack {
                                Text("Public profile")
                                Spacer()
                                Toggle("", isOn: $isPublicProfile)
                                    .labelsHidden()
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // ── CONNECTED SPONSORS (DISCLOSURE) ──────────────
                    Card {
                        DisclosureGroup(isExpanded: $sponsorsExpanded) {
                            VStack(alignment: .leading, spacing: 10) {
                                if sponsors.isEmpty {
                                    Text("No sponsors connected.")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(sponsors) { s in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(s.fullName).font(.subheadline.weight(.semibold))
                                            Text(s.id).font(.caption).foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                    }
                                }

                                HStack(spacing: 8) {
                                    TextField("Enter Sponsor User ID", text: $newSponsorID)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                        .padding(10)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Button("Add") { addSponsor() }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(newSponsorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }

                                if let errorMessage { Text(errorMessage).foregroundColor(.red).font(.caption) }
                                if let successMessage { Text(successMessage).foregroundColor(.green).font(.caption) }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text("Connected Sponsors")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: sponsorsExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disclosureGroupStyle(PlainDisclosureGroupStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // ── DEV: USER ID COPY (kept hidden in UI) ─────────
                    Card {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("User ID").font(.subheadline.weight(.semibold))
                                Text(userID).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                UIPasteboard.general.string = userID
                                showCopyAlert = true
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadUserData()
                loadTotalPoints()
            }
            .refreshable {
                await withCheckedContinuation { cont in
                    loadUserData()
                    loadTotalPoints() { cont.resume() }
                }
            }
            .alert("User ID copied to clipboard!", isPresented: $showCopyAlert) {
                Button("OK", role: .cancel) { }
            }
            // Background image like Leaderboard/MyChallenges
            .background(
                Image("leaderboard_bg")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.15)
                    .ignoresSafeArea()
            )
        }
    }

    // Derived display name (keeps working if full name missing)
    private var displayName: String {
        if !fullName.isEmpty { return fullName }
        if let emailComp = email.split(separator: "@").first {
            return String(emailComp)
        }
        return "My Name"
    }
}

// MARK: - Subviews

private struct ProfileHeaderCard: View {
    let fullName: String
    let subtitleTop: String
    let subtitleBottom: String
    let points: Int
    var onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color.orange, Color.indigo],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 170)

            HStack(alignment: .center, spacing: 16) {
                // Avatar placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 42, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    )
                    .frame(width: 84, height: 108)

                VStack(alignment: .leading, spacing: 6) {
                    Text(fullName)
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(subtitleTop)
                        .foregroundColor(.white.opacity(0.95))
                        .font(.subheadline.weight(.semibold))

                    Text(subtitleBottom)
                        .foregroundColor(.white.opacity(0.9))
                        .font(.subheadline)

                    HStack(spacing: 10) {
                        PointsPill(points: points)
                        Button("Edit Profile", action: onEdit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.indigo)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 8)
    }
}

private struct PointsPill: View {
    let points: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "seal.fill")
                .font(.subheadline)
            Text("\(points) Points")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.yellow.opacity(0.35))
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .clipShape(Capsule())
    }
}

private struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            trailing()
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}

private struct RowCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        Card { content() }
            .frame(maxWidth: .infinity)
    }
}

private struct StatCard: View {
    let primary: String
    let title: String
    let progress: Double
    var compact: Bool = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(primary)
                    .font(.title2.bold())
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                ProgressView(value: progress)
                    .tint(.indigo)
            }
        }
    }
}

private struct GoalProgressCard: View {
    let title: String
    let subtitle: String
    let current: Int
    let total: Int
    let footerLeft: String
    let footerRight: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                ProgressView(value: Double(current) / Double(total))
                    .tint(.indigo)
                    .padding(.top, 2)
                HStack {
                    Text(footerLeft).font(.footnote).foregroundColor(.secondary)
                    Spacer()
                    Text(footerRight).font(.footnote).foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct IconValuePill: View {
    let system: String
    let title: String
    let subtitle: String
    var body: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: system)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Firestore loaders

extension ProfileView {
    private func loadUserData() {
        guard let uid = user?.uid else { return }
        userID = uid

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Error loading user data: \(error.localizedDescription)")
                return
            }
            if let data = snapshot?.data() {
                fullName = data["fullName"] as? String ?? ""
                email    = data["email"] as? String ?? ""
                role     = data["role"] as? String ?? ""
                if let dobTimestamp = data["dateOfBirth"] as? Timestamp {
                    dateOfBirth = dobTimestamp.dateValue()
                }
                if let sponsorIDs = data["connectedSponsors"] as? [String] {
                    loadSponsorsDetails(ids: sponsorIDs)
                }
            }
        }
    }

    private func loadSponsorsDetails(ids: [String]) {
        sponsors.removeAll()
        let group = DispatchGroup()
        for sid in ids {
            group.enter()
            db.collection("users").document(sid).getDocument { snapshot, _ in
                defer { group.leave() }
                if let data = snapshot?.data() {
                    let name = (data["fullName"] as? String) ?? "Unknown"
                    DispatchQueue.main.async {
                        sponsors.append(Sponsor(id: sid, fullName: name))
                    }
                }
            }
        }
        group.notify(queue: .main) { }
    }

    private func addSponsor() {
        errorMessage = nil
        successMessage = nil

        let trimmedID = newSponsorID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, trimmedID != userID else {
            errorMessage = "Invalid Sponsor ID."
            return
        }
        guard !sponsors.contains(where: { $0.id == trimmedID }) else {
            errorMessage = "Sponsor already connected."
            return
        }

        db.collection("users").document(trimmedID).getDocument { snapshot, error in
            if let error = error {
                errorMessage = "Error checking sponsor ID: \(error.localizedDescription)"
                return
            }
            guard let data = snapshot?.data() else {
                errorMessage = "Sponsor ID not found."
                return
            }

            let updatedIDs = sponsors.map { $0.id } + [trimmedID]
            db.collection("users").document(userID).updateData([
                "connectedSponsors": updatedIDs
            ]) { error in
                if let error = error {
                    errorMessage = "Failed to add sponsor: \(error.localizedDescription)"
                } else {
                    let fullName = data["fullName"] as? String ?? "Unknown"
                    sponsors.append(Sponsor(id: trimmedID, fullName: fullName))
                    successMessage = "Sponsor added successfully!"
                    newSponsorID = ""
                }
            }
        }
    }

    /// Sums rewardPoints for completed challenges under users/{uid}/acceptedChallenges
    private func loadTotalPoints(completion: (() -> Void)? = nil) {
        guard let uid = user?.uid else { completion?(); return }
        let completedState = "completed"
        db.collection("users")
            .document(uid)
            .collection("acceptedChallenges")
            .whereField("state", isEqualTo: completedState)
            .getDocuments { snapshot, _ in
                let sum = snapshot?.documents.reduce(0) { acc, doc in
                    acc + (doc.data()["rewardPoints"] as? Int ?? 0)
                } ?? 0
                totalPoints = sum
                completion?()
            }
    }
}

import CoreImage
import CoreImage.CIFilterBuiltins

private struct QRCodeSheet: View {
    let userID: String
    @Environment(\.dismiss) private var dismiss

    private var payload: String {
        "https://sponup.app/u/\(userID)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Show this code to connect or scan")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                QRCodeView(text: payload)
                    .frame(width: 260, height: 260)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08)))

                ShareLink(item: URL(string: payload)!) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }

                Text("ID: \(userID)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(24)
            .navigationTitle("My QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct QRCodeView: View {
    let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let uiImage = makeQRCode(from: text) {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .accessibilityLabel("QR code for profile link")
        } else {
            ZStack {
                Color(.systemGray6)
                Text("Unable to generate QR")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func makeQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = outputImage.transformed(by: transform)

        if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

struct PlainDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { configuration.isExpanded.toggle() }) {
                configuration.label
            }
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
