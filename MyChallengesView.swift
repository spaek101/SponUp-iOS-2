import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif
import UniformTypeIdentifiers



struct MyChallengesView: View {
    @State private var acceptedChallenges: [Challenge] = []

    // Tabs
    private enum ChallengeScope: String, CaseIterable, Identifiable {
        case game = "Game Challenges"
        case training = "Training Challenges"
        var id: String { rawValue }
    }
    @State private var scope: ChallengeScope = .game

    private let db = Firestore.firestore()
    private let userID = Auth.auth().currentUser?.uid
    #if canImport(FirebaseFunctions)
    private let functions = Functions.functions()
    #endif

    // Upload UI state
    @State private var pendingUploadChallenge: Challenge?
    @State private var showUploadChoice = false
    @State private var showPhotoPicker = false
    @State private var showDocPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var toastText: String?

    // MARK: - Filters (robust)

    private var filteredChallenges: [Challenge] {
        let list = acceptedChallenges.filter { ch in
            switch scope {
            case .game:     return isGameChallenge(ch)
            case .training: return isTrainingChallenge(ch)
            }
        }
        return list.sorted { ($0.acceptedDate ?? .distantPast) > ($1.acceptedDate ?? .distantPast) }
    }

    private func isGameChallenge(_ c: Challenge) -> Bool {
        if c.category == ChallengeCategory(rawValue: "reward") { return true }
        if c.category == ChallengeCategory(rawValue: "training") { return false }
        let cat = c.category.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cat == "reward" || cat.contains("reward") { return true }
        if cat == "training" || cat.contains("training") { return false }
        if let eid = c.eventID, !eid.isEmpty { return true }
        return false
    }

    private func isTrainingChallenge(_ c: Challenge) -> Bool {
        let cat = c.category.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cat == "training" || cat.contains("training") { return true }
        if cat == "reward" || cat.contains("reward") { return false }
        if let eid = c.eventID, !eid.isEmpty { return false }
        return true
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Tabs
                        Picker("", selection: $scope) {
                            ForEach(ChallengeScope.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if filteredChallenges.isEmpty {
                            Text(emptyStateText)
                                .foregroundColor(.white.opacity(0.9))
                                .font(.title3.weight(.semibold))
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(filteredChallenges) { challenge in
                                    // Card-like row with Upload button (right side)
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(challenge.title)
                                                    .font(.headline)
                                                    .foregroundColor(.black)
                                                Text(rewardLine(for: challenge))
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Button {
                                                uploadProof(for: challenge)
                                            } label: {
                                                Label("Upload", systemImage: "square.and.arrow.up")
                                                    .font(.subheadline.bold())
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.brown)
                                            .disabled(isUploading)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 40)
                        }
                    }
                    .padding(.vertical)
                }

                // Simple uploading overlay
                if isUploading {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Uploading…")
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Toast
                if let t = toastText {
                    VStack {
                        Spacer()
                        Text(t)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(14)
                            .shadow(radius: 4)
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { toastText = nil }
                        }
                    }
                }
            }
            .navigationTitle("My Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                Image("leaderboard_bg")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.15)
                    .ignoresSafeArea()
            )
            .onAppear { loadAcceptedChallenges() }

            // Upload choice dialog
            .confirmationDialog(
                "Upload proof",
                isPresented: $showUploadChoice,
                presenting: pendingUploadChallenge
            ) { ch in
                Button("Photo or Video") { showPhotoPicker = true }
                Button("Document (PDF / CSV / Image)") { showDocPicker = true }
                Button("Cancel", role: .cancel) { }
            } message: { ch in
                Text(ch.title)
            }

            // PhotosPicker (images/videos)
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            )
            .onChange(of: selectedPhotoItem) { _ in
                Task { await handlePickedPhotoItem() }
            }

            // DocumentPicker (PDF/CSV/Image)
            .sheet(isPresented: $showDocPicker) {
                DocumentPicker { url in
                    Task { await handlePickedDocURL(url) }
                }
            }

            // Error alert
            .alert("Upload Failed", isPresented: .constant(uploadError != nil), presenting: uploadError) { _ in
                Button("OK", role: .cancel) { uploadError = nil }
            } message: { err in
                Text(err)
            }
        }
    }

    private var emptyStateText: String {
        switch scope {
        case .game:     return "No game challenges yet."
        case .training: return "No training challenges yet."
        }
    }

    // MARK: - Helpers

    private func rewardLine(for c: Challenge) -> String {
        let cashStr: String? = {
            if let cash = c.rewardCash, cash > 0 {
                return currencyFormatter.string(from: NSNumber(value: cash))
            }
            return nil
        }()

        let pts = c.rewardPoints ?? 0
        switch (cashStr, pts) {
        case let (cash?, p) where p > 0: return "\(cash) +\(p) pts"
        case let (cash?, _):             return cash
        case (_, let p) where p > 0:     return "+\(p) pts"
        default:                         return "+0 pts"
        }
    }

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    private func uploadProof(for challenge: Challenge) {
        pendingUploadChallenge = challenge
        showUploadChoice = true
    }

    // MARK: - Pickers → Storage → Submission → AI verify

    private func storagePath(for challenge: Challenge, ext: String) -> String {
        let uid = userID ?? "anon"
        let cid = challenge.id ?? UUID().uuidString
        let filename = "\(UUID().uuidString).\(ext)"
        return "users/\(uid)/proofs/\(cid)/\(filename)"
    }

    private func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "heic":        return "image/heic"
        case "mov":         return "video/quicktime"
        case "mp4":         return "video/mp4"
        case "pdf":         return "application/pdf"
        case "csv":         return "text/csv"
        default:            return "application/octet-stream"
        }
    }

    private func listenForSubmissionResult(uid: String, docID: String) {
        db.collection("users").document(uid)
            .collection("challengeSubmissions")
            .document(docID)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }
                let status = (data["status"] as? String) ?? "pending"
                let verdict = (data["aiVerdict"] as? String) ?? ""
                if status == "passed" || verdict == "passed" {
                    toastText = "✅ Verified!"
                    // Optionally mark challenge completed locally for immediate UX:
                    if let chID = data["challengeID"] as? String,
                       let idx = acceptedChallenges.firstIndex(where: { $0.id == chID }) {
                        var ch = acceptedChallenges[idx]
                        ch.state = .completed
                        acceptedChallenges[idx] = ch
                    }
                    // Optionally update Firestore official record here...
                } else if status == "failed" || verdict == "failed" {
                    toastText = "❌ Not enough proof. Try again."
                }
            }
    }

    private func createSubmissionRecord(uid: String,
                                        challenge: Challenge,
                                        storagePath: String,
                                        mime: String,
                                        completion: @escaping (_ docID: String?) -> Void) {
        let ref = db.collection("users").document(uid)
            .collection("challengeSubmissions").document()

        let payload: [String: Any] = [
            "id": ref.documentID,
            "challengeID": challenge.id ?? "",
            "type": (isTrainingChallenge(challenge) ? "training" : "game"),
            "title": challenge.title,
            "storagePath": storagePath,
            "contentType": mime,
            "status": "pending",
            "aiVerdict": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]

        ref.setData(payload) { err in
            if let err = err {
                uploadError = "Could not create submission: \(err.localizedDescription)"
                completion(nil)
                return
            }
            completion(ref.documentID)
            listenForSubmissionResult(uid: uid, docID: ref.documentID)
        }
    }

    private func triggerAIVerification(uid: String,
                                       submissionID: String) {
        // Optional Cloud Function (if you added FirebaseFunctions)
        #if canImport(FirebaseFunctions)
        functions.httpsCallable("aiVerifyChallengeProof").call([
            "uid": uid,
            "submissionID": submissionID
        ]) { result, error in
            if let error = error {
                print("aiVerifyChallengeProof error:", error.localizedDescription)
            }
        }
        #endif
    }

    private func uploadDataToStorage(_ data: Data,
                                     ext: String,
                                     challenge: Challenge) async {
        guard let uid = userID else { return }
        isUploading = true
        defer { isUploading = false }

        let path = storagePath(for: challenge, ext: ext)
        let ref = Storage.storage().reference().child(path)
        let meta = StorageMetadata()
        meta.contentType = contentType(for: ext)

        do {
            _ = try await ref.putDataAsync(data, metadata: meta)
            createSubmissionRecord(uid: uid, challenge: challenge, storagePath: path, mime: meta.contentType ?? "application/octet-stream") { docID in
                guard let docID = docID else { return }
                triggerAIVerification(uid: uid, submissionID: docID)
                toastText = "✅ Uploaded. Verifying…"
            }
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
    }

    private func uploadFileURLToStorage(_ fileURL: URL,
                                        ext: String,
                                        challenge: Challenge) async {
        guard let uid = userID else { return }
        isUploading = true
        defer { isUploading = false }

        let path = storagePath(for: challenge, ext: ext)
        let ref = Storage.storage().reference().child(path)
        let meta = StorageMetadata()
        meta.contentType = contentType(for: ext)

        do {
            _ = try await ref.putFileAsync(from: fileURL, metadata: meta)
            createSubmissionRecord(uid: uid, challenge: challenge, storagePath: path, mime: meta.contentType ?? "application/octet-stream") { docID in
                guard let docID = docID else { return }
                triggerAIVerification(uid: uid, submissionID: docID)
                toastText = "✅ Uploaded. Verifying…"
            }
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Picker handlers

    private func handlePickedPhotoItem() async {
        guard let item = selectedPhotoItem,
              let challenge = pendingUploadChallenge else { return }
        defer {
            selectedPhotoItem = nil
            pendingUploadChallenge = nil
        }

        // Try loading as Data first (works for images and many videos)
        if let (data, ext) = await loadDataAndExt(from: item) {
            await uploadDataToStorage(data, ext: ext, challenge: challenge)
            return
        }

        // iOS 17+: fall back to a temp file URL (better for large videos)
        if #available(iOS 17.0, *),
           let (url, ext) = await loadFileURLAndExt(from: item) {
            await uploadFileURLToStorage(url, ext: ext, challenge: challenge)
            return
        }

        uploadError = "Couldn’t load selected media."
    }

    private func loadDataAndExt(from item: PhotosPickerItem) async -> (Data, String)? {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let ut = item.supportedContentTypes.first
                let ext = ut?.preferredFilenameExtension?.lowercased() ?? guessExt(from: ut) ?? "bin"
                return (data, ext)
            }
        } catch {
            // fall through to URL approach on iOS 17+
        }
        return nil
    }

    @available(iOS 17.0, *)
    private func loadFileURLAndExt(from item: PhotosPickerItem) async -> (URL, String)? {
        do {
            if let url = try await item.loadTransferable(type: URL.self) {
                let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension.lowercased()
                return (url, ext)
            }
        } catch { }
        return nil
    }

    private func guessExt(from ut: UTType?) -> String? {
        guard let ut else { return nil }
        if ut.conforms(to: .png)                { return "png" }
        if ut.conforms(to: .jpeg)               { return "jpg" }
        if ut.conforms(to: .heic)               { return "heic" }
        if ut.conforms(to: .mpeg4Movie)         { return "mp4" }
        if ut.conforms(to: .movie)              { return "mov" }
        if ut.conforms(to: .pdf)                { return "pdf" }
        if ut.conforms(to: .commaSeparatedText) { return "csv" }
        return nil
    }


    private func handlePickedDocURL(_ url: URL?) async {
        guard let url, let challenge = pendingUploadChallenge else { return }
        defer { pendingUploadChallenge = nil }

        let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
        await uploadFileURLToStorage(url, ext: ext, challenge: challenge)
    }

    // MARK: - Data loading

    private func loadAcceptedChallenges() {
        guard let uid = userID else { return }
        db.collection("users")
            .document(uid)
            .collection("acceptedChallenges")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching accepted challenges: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }

                var loaded: [Challenge] = []
                for doc in documents {
                    if let challenge = parseChallengeData(doc.data()) {
                        loaded.append(challenge)
                    }
                }
                DispatchQueue.main.async {
                    acceptedChallenges = loaded
                }
            }
    }

    private func parseChallengeData(_ data: [String: Any]) -> Challenge? {
        guard
            let idString      = data["id"] as? String,
            let categoryRaw   = data["category"] as? String,
            let category      = ChallengeCategory(rawValue: categoryRaw),
            let title         = data["title"] as? String,
            let typeRaw       = data["type"] as? String,
            let type          = ChallengeType(rawValue: typeRaw),
            let difficultyRaw = data["difficulty"] as? String,
            let difficulty    = Difficulty(rawValue: difficultyRaw),
            let stateRaw      = data["state"] as? String,
            let state         = ChallengeState(rawValue: stateRaw)
        else { return nil }

        let rewardCash    = data["rewardCash"] as? Double
        let rewardPoints  = data["rewardPoints"] as? Int
        let timeRemaining = data["timeRemaining"] as? TimeInterval

        let acceptedDate: Date? = (data["acceptedDate"] as? Timestamp)?.dateValue()
        let startAt: Date?      = (data["startAt"] as? Timestamp)?.dateValue()

        let eventID   = data["eventID"] as? String
        let athleteID = data["athleteID"] as? String
        let imageURL  = data["imageURL"] as? String

        return Challenge(
            id:            idString,
            category:      category,
            title:         title,
            type:          type,
            difficulty:    difficulty,
            rewardCash:    rewardCash,
            rewardPoints:  rewardPoints,
            timeRemaining: timeRemaining,
            state:         state,
            acceptedDate:  acceptedDate,
            startAt:       startAt,
            eventID:       eventID,
            athleteID:     athleteID,
            imageURL:      imageURL
        )
    }
}

// MARK: - Simple DocumentPicker (PDF/CSV/Image)

private struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .commaSeparatedText, .png, .jpeg, .heic]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}
