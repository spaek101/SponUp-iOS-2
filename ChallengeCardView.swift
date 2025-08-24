import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let onClaim: (Challenge) -> Void

    // Context flags
    var fundButton: Bool = false          // sponsor context
    var isFunded: Bool = false            // already funded in backend
    var isSelected: Bool = false          // in sponsor cart
    var showCash: Bool = true             // <<< the ONLY switch for showing cash
    
    @State private var isPressed = false
    @State private var showReward = false
    @State private var animateCard = false

    // If a sponsored item didn't come with cash, default by difficulty (sponsor side)
    private var defaultCashFromDifficulty: Int {
        switch challenge.difficulty {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 20
        }
    }

    // What the CTA should say
    private var buttonTitle: String {
        if fundButton {
            if isFunded { return "Funded" }
            if isSelected { return "Remove" }
            return "Fund"
        } else {
            return isFunded ? "Remove" : "Accept"
        }
    }

    private var buttonStyle: some ButtonStyle {
        if fundButton {
            if isFunded { return AnyButtonStyle(DisabledButtonStyle()) }
            return isSelected ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle())
        } else {
            return isSelected ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle())
        }
    }

    // Single source of truth for the reward line
    private var rewardLine: String {
        let pts = challenge.rewardPoints ?? 0

        // If we're NOT supposed to show cash (Challenge/Training tabs),
        // always return points-only.
        guard showCash else { return "\(pts) pts" }

        // Otherwise (Sponsored tab), show cash + points.
        let cash = Int(challenge.rewardCash ?? 0)
        if cash > 0 {
            return "$\(cash) + \(pts) pts"
        } else {
            // Sponsored but no explicit cash — fall back by difficulty.
            return "$\(defaultCashFromDifficulty) + \(pts) pts"
        }
    }
    
    // Difficulty color
    private var difficultyColor: Color {
        switch challenge.difficulty {
        case .easy: return AppColors.success
        case .medium: return AppColors.warning
        case .hard: return AppColors.error
        }
    }
    
    // Difficulty icon
    private var difficultyIcon: String {
        switch challenge.difficulty {
        case .easy: return "star.fill"
        case .medium: return "star.leadinghalf.filled"
        case .hard: return "star.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with image and difficulty badge
            ZStack(alignment: .topTrailing) {
                // Challenge image
                if let uiImage = UIImage(named: challenge.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                        .overlay(
                            // Gradient overlay for better text readability
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    ZStack {
                        AppGradients.surface
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.primary.opacity(0.6))
                    }
                    .frame(height: 140)
                }
                
                // Difficulty badge
                VStack(spacing: 4) {
                    Image(systemName: difficultyIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(challenge.difficulty.rawValue.capitalized)
                        .font(AppTypography.caption2.weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(difficultyColor)
                        .shadow(color: difficultyColor.opacity(0.4), radius: 4, x: 0, y: 2)
                )
                .padding(AppSpacing.sm)
            }
            
            // Content area
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Title with category icon
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 24, height: 24)
                    
                    Text(challenge.title)
                        .font(AppTypography.headline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Reward section with animation
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .scaleEffect(showReward ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: showReward)
                    
                    Text(rewardLine)
                        .font(AppTypography.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Action button
                Button(action: {
                    guard !(fundButton && isFunded) else { return }
                    
                    HapticManager.impact(style: .medium)
                    onClaim(challenge)
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(buttonTitle)
                            .font(AppTypography.headline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(buttonBackgroundColor)
                    )
                }
                .buttonStyle(buttonStyle)
                .disabled(fundButton && isFunded)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
        .shadow(color: AppShadows.medium.color, radius: AppShadows.medium.radius, x: AppShadows.medium.x, y: AppShadows.medium.y)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onAppear {
            animateCard = true
            showReward = true
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }
    }
    
    // Category icon mapping
    private var categoryIcon: String {
        switch challenge.category {
        case .batting: return "baseball.fill"
        case .pitching: return "target"
        case .catching: return "hand.raised.fill"
        case .fielding: return "figure.baseball"
        case .baseRunning: return "figure.run"
        }
    }
    
    // Button icon mapping
    private var buttonIcon: String {
        if fundButton {
            if isFunded { return "checkmark.circle.fill" }
            if isSelected { return "minus.circle.fill" }
            return "plus.circle.fill"
        } else {
            return isFunded ? "minus.circle.fill" : "plus.circle.fill"
        }
    }
    
    // Button background color
    private var buttonBackgroundColor: Color {
        if fundButton {
            if isFunded { return AppColors.textSecondary }
            return isSelected ? AppColors.warning : AppColors.accent
        } else {
            return isFunded ? AppColors.warning : AppColors.accent
        }
    }
}

// MARK: - Button Style Wrapper
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Disabled Button Style
struct DisabledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(AppColors.textSecondary)
            )
            .opacity(0.6)
    }
}

// MARK: - Corner Radius Extension (keeping for compatibility)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 12.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    VStack(spacing: 20) {
        ChallengeCardView(
            challenge: Challenge(
                category: .batting,
                title: "Hit a Home Run",
                type: .reward,
                difficulty: .hard,
                rewardPoints: 500,
                state: .available
            ),
            onClaim: { _ in }
        )
        
        ChallengeCardView(
            challenge: Challenge(
                category: .pitching,
                title: "Pitch a Perfect Game",
                type: .training,
                difficulty: .medium,
                rewardPoints: 200,
                state: .available
            ),
            onClaim: { _ in },
            showCash: false
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
