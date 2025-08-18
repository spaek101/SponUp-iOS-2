import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

// MARK: — Supporting Types

enum ProfileTab: String, CaseIterable, Identifiable {
    case active    = "Active"
    case pending   = "Pending Approval"
    case completed = "Completed"
    var id: String { rawValue }
}

struct SponsorChallenge: Identifiable {
    let id: String
    let athleteName: String
    let title: String
    let amount: Double
    let dueDate: Date
    let state: ProfileTab
}

struct PendingSubmission: Identifiable {
    let id: String
    let athleteName: String
    let challengeTitle: String
    let amount: Double
    let dueDate: Date
    let mediaImage: UIImage?    // thumbnail (image or video icon)
}

struct FilledButton: ButtonStyle {
    let backgroundColor: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: — SponsorProfileView

struct SponsorProfileView: View {
    // MARK: — Profile Info (LIVE from Firestore/Auth)
    @State private var fullName: String    = ""
    @State private var email: String       = ""
    @State private var dateOfBirth: Date   = .distantPast
    @State private var createdAt: Date     = .distantPast
    @State private var userID: String      = ""

    @State private var profileImage: UIImage?      // from Firestore photoURL (or Auth) if present
    @State private var showImagePicker = false
    @State private var showEditModal   = false
    @State private var showCopyToast   = false

    // MARK: — Tabs data (mock until wired to backend)
    @State private var totalFunded : Double = 0
    @State private var challenges  : [SponsorChallenge] = []
    @State private var pendingSubs : [PendingSubmission] = []
    @State private var selectedTab : ProfileTab = .active

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {

                        // ── Header (profile photo) ───────────────────────
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let img = profileImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 4)
                            .onTapGesture { showImagePicker = true }

                            Button { showImagePicker = true } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(Color.white))
                                    .offset(x: 5, y: 5)
                            }
                        }
                        .padding(.top, 32)

                        HStack(spacing: 8) {
                            Text(fullName.isEmpty ? "My Name" : fullName)
                                .font(.largeTitle.bold())
                            Button { showEditModal = true } label: {
                                Image(systemName: "pencil").foregroundColor(.blue)
                            }
                        }

                        // Sponsor since = createdAt from Firestore/Auth
                        if createdAt != .distantPast {
                            Text("Sponsor since \(formattedDate(createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // ── Info rows (live) ─────────────────────────────
                        VStack(spacing: 12) {
                            if !email.isEmpty {
                                InfoRow(label: "Email", value: email)
                            }
                            if dateOfBirth != .distantPast {
                                InfoRow(label: "Date of Birth", value: formattedDate(dateOfBirth))
                            }
                            if !userID.isEmpty {
                                InfoRow(label: "User ID", value: userID, copyable: true) {
                                    withAnimation { showCopyToast = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        withAnimation { showCopyToast = false }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // ── Wallet Summary (mock totalFunded) ───────────
                        VStack(alignment: .leading, spacing: 4) {
                            Text("$\(Int(totalFunded))").font(.title2.bold())
                            Text("Total Funded").font(.caption).foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6).cornerRadius(12))
                        .padding(.horizontal)

                        // ── Tabs ─────────────────────────────────────────
                        Picker("", selection: $selectedTab) {
                            ForEach(ProfileTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // ── Tab Content (mock) ───────────────────────────
                        Group {
                            switch selectedTab {
                            case .active, .completed:
                                let items = challenges.filter { $0.state == selectedTab }
                                if items.isEmpty {
                                    Text("No \(selectedTab.rawValue.lowercased()) challenges.")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 16)
                                } else {
                                    VStack(spacing: 16) {
                                        ForEach(items) { chal in
                                            HStack(alignment: .top, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text(chal.athleteName).font(.headline)
                                                    Text(chal.title).font(.subheadline)
                                                    Text("Due \(formattedDate(chal.dueDate))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Text("$\(Int(chal.amount))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.black)
                                            }
                                            .padding()
                                            .background(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                            case .pending:
                                if pendingSubs.isEmpty {
                                    Text("No submissions awaiting approval.")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 16)
                                } else {
                                    VStack(spacing: 16) {
                                        ForEach(pendingSubs) { sub in
                                            VStack(spacing: 12) {
                                                HStack(alignment: .top, spacing: 12) {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text(sub.athleteName).font(.headline)
                                                        Text(sub.challengeTitle).font(.subheadline)
                                                        Text("$\(Int(sub.amount))")
                                                            .font(.subheadline)
                                                            .foregroundColor(.black)
                                                        Text("Due \(formattedDate(sub.dueDate))")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    if let img = sub.mediaImage {
                                                        Image(uiImage: img)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 80, height: 80)
                                                            .clipped()
                                                            .cornerRadius(8)
                                                    } else {
                                                        Image(systemName: "video.fill")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 80, height: 80)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                HStack(spacing: 12) {
                                                    Button("Approve") { }
                                                        .buttonStyle(FilledButton(backgroundColor: .green))
                                                    Button("Deny") { }
                                                        .buttonStyle(FilledButton(backgroundColor: .red))
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding()
                                            .background(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        // ────────────────────────────────────────────────

                        // ── YTD Summary & Footer ─────────────────────────
                        NavigationLink { /* wire up your summary view */ } label: {
                            Text("YTD Donation Summary")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        HStack {
                            Button("Log Out") { }
                                .font(.footnote)
                                .foregroundColor(.red)
                            Spacer()
                            Button("Delete Account") { }
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }

                // ── Toast overlay ───────────────────────────
                if showCopyToast {
                    Text("User ID copied to clipboard!")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: showCopyToast)
                }
            }
            .navigationTitle("Sponsor Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 24, height: 24)
                            Text("?")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .sheet(isPresented: $showEditModal) {
                EditNameDOBView(fullName: $fullName, dateOfBirth: $dateOfBirth)
            }
            .onAppear {
                loadProfileFromFirestore()
                loadTabMocks() // keep mock tabs unless you have backend for them
            }
        }
    }

    // MARK: — Firestore loaders (LIVE)

    private func loadProfileFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        userID = uid

        // fallbacks from Auth first (quick)
        let authUser = Auth.auth().currentUser
        if email.isEmpty { email = authUser?.email ?? "" }
        if fullName.isEmpty { fullName = authUser?.displayName ?? "" }
        if profileImage == nil, let url = authUser?.photoURL {
            fetchImage(url) { self.profileImage = $0 }
        }

        // users/{uid} expected fields:
        // fullName: String
        // email: String
        // dateOfBirth: Timestamp
        // createdAt: Timestamp
        // photoURL: String (optional)
        db.collection("users").document(uid).getDocument { snap, _ in
            guard let data = snap?.data() else { return }

            if let name = data["fullName"] as? String { self.fullName = name }
            if let e = data["email"] as? String { self.email = e }
            if let ts = data["dateOfBirth"] as? Timestamp { self.dateOfBirth = ts.dateValue() }
            if let ct = data["createdAt"] as? Timestamp { self.createdAt = ct.dateValue() }

            if let photoURLString = data["photoURL"] as? String,
               let url = URL(string: photoURLString) {
                fetchImage(url) { self.profileImage = $0 }
            }
        }
    }

    private func fetchImage(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(img) }
        }.resume()
    }

    // MARK: — Tab mocks (kept)
    private func loadTabMocks() {
        let now = Date()
        challenges = [
            .init(id: "1", athleteName: "Alice", title: "Hit a Home Run",   amount: 50, dueDate: now.addingTimeInterval(86400 * 3), state: .active),
            .init(id: "2", athleteName: "Bob",   title: "Steal a Base",      amount: 40, dueDate: now.addingTimeInterval(86400 * 5), state: .active),
            .init(id: "3", athleteName: "Cara",  title: "Catch 10 Fly Balls",amount: 60, dueDate: now.addingTimeInterval(86400 * 2), state: .active),
            .init(id: "4", athleteName: "Evan",  title: "Throw 70 Pitches",  amount: 45, dueDate: now.addingTimeInterval(86400 * 7), state: .completed),
        ]
        totalFunded = challenges.map(\.amount).reduce(0, +)

        pendingSubs = [
            .init(id: "a", athleteName: "Dave",  challengeTitle: "Strike Out 5", amount: 75, dueDate: now.addingTimeInterval(86400 * 1), mediaImage: UIImage(named: "Mock_Stats1")),
            .init(id: "b", athleteName: "Emma",  challengeTitle: "Sprint 100m",  amount: 30, dueDate: now.addingTimeInterval(86400 * 4), mediaImage: UIImage(named: "Mock_Stats2")),
            .init(id: "c", athleteName: "Frank", challengeTitle: "Field 20 Hits",amount: 55, dueDate: now.addingTimeInterval(86400 * 2), mediaImage: UIImage(named: "Mock_Video")),
        ]
    }

    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}

// MARK: — InfoRow

struct InfoRow: View {
    let label: String
    let value: String
    var copyable = false
    var onCopy: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
            if copyable {
                Button {
                    UIPasteboard.general.string = value
                    onCopy?()   // notify parent for toast
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 4)
            }
        }
    }
}

// MARK: — ImagePicker & EditNameDOBView (unchanged)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var mode
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(this: self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(this parent: ImagePicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController,
                    didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let prov = results.first?.itemProvider,
                  prov.canLoadObject(ofClass: UIImage.self)
            else { return }
            prov.loadObject(ofClass: UIImage.self) { object, _ in
                if let img = object as? UIImage {
                    DispatchQueue.main.async { self.parent.image = img }
                }
            }
        }
    }
}

struct EditNameDOBView: View {
    @Binding var fullName: String
    @Binding var dateOfBirth: Date
    @Environment(\.presentationMode) private var mode

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Full Name", text: $fullName)
                }
                Section("Date of Birth") {
                    DatePicker("Birthdate", selection: $dateOfBirth, displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { mode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
