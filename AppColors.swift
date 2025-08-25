import SwiftUI

// MARK: - App Colors
/// Centralized color system for the SponUp app
/// All colors support both light and dark modes
struct AppColors {
    // MARK: - Brand Colors
    static let primary = Color("AppTheme")
    static let accent = Color("AppAccent")
    
    // MARK: - Surface Colors
    static let surface = Color("AppSurface")
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    
    // MARK: - Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    
    // MARK: - Semantic Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    // MARK: - Challenge Difficulty Colors
    static let challengeEasy = Color("ChallengeEasy")
    static let challengeMedium = Color("ChallengeMedium")
    static let challengeHard = Color("ChallengeHard")
    
    // MARK: - Utility Colors
    static let border = Color("BorderColor")
    static let shadow = Color("ShadowColor")
    static let overlay = Color("OverlayColor")
    
    // MARK: - Gradient Colors
    static let gradientStart = Color("GradientStart")
    static let gradientEnd = Color("GradientEnd")
}

// MARK: - Color Extensions
extension AppColors {
    /// Returns a color with the specified opacity
    static func withOpacity(_ color: Color, _ opacity: Double) -> Color {
        return color.opacity(opacity)
    }
    
    /// Returns the appropriate challenge difficulty color
    /// Note: Difficulty enum is defined in Models.swift
    static func forDifficulty(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy:
            return challengeEasy
        case .medium:
            return challengeMedium
        case .hard:
            return challengeHard
        }
    }
}

// MARK: - Difficulty Enum
// Note: Difficulty enum is defined in Models.swift
