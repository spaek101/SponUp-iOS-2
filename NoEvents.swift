//
//  NoEvents.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/21/25.
//


import SwiftUI

struct NoEvents: View {
    /// Optional handler if you want to hook into your own nav/sheet.
    var onAddEvent: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Image("NoEvents")                 // <- add this image to Assets
                .resizable()
                .scaledToFill()
                .clipped()

            // subtle bottom fade so text is readable on light images
            LinearGradient(
                colors: [.clear, .white.opacity(0.35)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                Spacer()
                Text("DON'T FORGET TO ADD YOUR GAMES!")
                    .font(.headline.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.88))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)


                Button(action: { onAddEvent?() }) {
                    Text("Add Event")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
                Spacer().frame(height: 8)
            }
            .padding(16)
        }
        .contentShape(Rectangle())
    }
}
