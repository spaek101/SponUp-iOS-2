import SwiftUI

struct WelcomeHeader: View {
    let userFirstName: String
    let userLastName: String
    
    var body: some View {
        HStack {
            Spacer()
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: 8) {
                    Text("Welcome! \(userFirstName) \(userLastName)")
                        .foregroundColor(.black)
                        .font(.subheadline)
                        .lineLimit(1)

                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.black)
                        .font(.title2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

