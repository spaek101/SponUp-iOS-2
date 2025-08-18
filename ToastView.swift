import SwiftUI



struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
