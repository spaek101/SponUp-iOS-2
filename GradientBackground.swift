// GradientBackground.swift

import SwiftUI

/// Full‑screen rainbow gradient that matches the design mock.
struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.42, green: 0.17, blue: 0.99), location: 0.00), // deep purple
                .init(color: Color(red: 0.11, green: 0.55, blue: 1.00), location: 0.25), // bright blue
                .init(color: Color(red: 0.00, green: 0.84, blue: 0.75), location: 0.55), // teal‑green
                .init(color: Color(red: 0.98, green: 0.34, blue: 0.65), location: 1.00)  // pink‑magenta
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
