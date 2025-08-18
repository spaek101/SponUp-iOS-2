//
//  FilterChip.swift
//  SponUp 2.0
//

import SwiftUI

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    /// Choose a fill colour based on chip label (green for “event” / pink for “training”)
    private var fillColour: Color {
        if label.lowercased().contains("event") {
            return Color(red: 0.17, green: 0.85, blue: 0.70)   // light mint‑green
        } else {
            return Color(red: 0.96, green: 0.56, blue: 0.74)   // light pastel‑pink
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                .background(
                    Capsule()
                        .fill(isSelected ? fillColour : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.white.opacity(0.4),
                            lineWidth: 1
                        )
                )
                // light shadow only when filled
                .shadow(color: isSelected ? .black.opacity(0.18) : .clear,
                        radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)      // no default button styling
        .contentShape(Capsule())  // full pill tap area
    }
}
