import SwiftUI

struct YourRank: View {
    let rank: Int?    // << optional

    var body: some View {
        HStack {
            Text("Your current ranking:")
                .font(.headline)
                .foregroundColor(.black)

            Spacer()

            Text(rankText)
                .font(.title2.bold())
                .foregroundColor(.blue) // pick a visible color on white
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var rankText: String {
        if let r = rank, r > 0 { return "#\(r)" }
        return "—"
    }
}
