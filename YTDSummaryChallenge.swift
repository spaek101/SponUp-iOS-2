import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct YTDSummaryChallenge: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let releasedAt: Date
    let athleteName: String
}

struct WalletDashboardView: View {
    @State private var balance: Double = 0.0
    @State private var challenges: [YTDSummaryChallenge] = []
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear-4...currentYear).reversed()
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Balance Card
                VStack(spacing: 10) {
                    Text("Account balance")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("$\(String(format: "%.2f", balance))")
                        .font(.system(size: 32, weight: .bold))

                    Text("1289440585") // Placeholder
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Year Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(years, id: \.self) { year in
                            yearTab(year: year, isSelected: year == selectedYear)
                                .onTapGesture {
                                    selectedYear = year
                                    // TODO: Filter challenges by selectedYear if needed
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Yearly Challenge List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YTD Challenges")
                            .font(.headline)
                        Spacer()
                        Button("see all") { }
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    // Column Headers
                    HStack(spacing: 8) {
                        Text("Date")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        Text("Challenge")
                            .font(.caption)
                            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                        Text("Amount")
                            .font(.caption)
                            .frame(width: 60, alignment: .trailing)
                        Text("Released")
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        Text("Athlete")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)

                    ForEach(challenges.sorted(by: { $0.releasedAt > $1.releasedAt })) { chal in
                        HStack(spacing: 8) {
                            Text(formattedDate(chal.releasedAt))
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)

                            Text(chal.title)
                                .font(.caption)
                                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)

                            Text("$\(Int(chal.amount))")
                                .font(.caption)
                                .frame(width: 60, alignment: .trailing)

                            Text(formattedDate(chal.releasedAt))
                                .font(.caption)
                                .frame(width: 70, alignment: .leading)

                            Text(chal.athleteName)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.top)

                Spacer()
            }
            .padding()
            .navigationTitle("Welcome back")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Image(systemName: "bell"))
            .onAppear {
                loadChallengeData()
            }
        }
    }

    // MARK: - Components

    private func yearTab(year: Int, isSelected: Bool) -> some View {
        Text(String(year))
            .font(.caption)
            .foregroundColor(isSelected ? .white : Color(.darkGray))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.gray.opacity(0.8) : Color.gray.opacity(0.3))
            .cornerRadius(12)
            .frame(minWidth: 50)
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }

    // MARK: - Firestore Loader

    private func loadChallengeData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users")
            .document(uid)
            .collection("fundedChallenges")
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                var total: Double = 0
                let items = docs.compactMap { doc -> YTDSummaryChallenge? in
                    let data = doc.data()
                    let title = data["title"] as? String ?? "Untitled"
                    let amount = data["rewardCash"] as? Double ?? 0
                    let releasedAt = (data["releasedAt"] as? Timestamp)?.dateValue() ?? Date()
                    let athlete = data["athleteName"] as? String ?? "Unknown"

                    total += amount

                    return YTDSummaryChallenge(
                        id: doc.documentID,
                        title: title,
                        amount: amount,
                        releasedAt: releasedAt,
                        athleteName: athlete
                    )
                }

                DispatchQueue.main.async {
                    self.challenges = items
                    self.balance = total
                }
            }
    }
}
