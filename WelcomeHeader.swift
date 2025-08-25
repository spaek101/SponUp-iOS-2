import SwiftUI


struct WelcomeHeader: View {
    enum Kind {
        case athlete(points: Int, cash: Int)
        case sponsor(balance: Double, compact: Bool = false, onTopUp: (() -> Void)? = nil)
    }

    let userFirstName: String
    let userLastName: String
    let kind: Kind
    
    @State private var isAnimating = false
    @State private var showConfetti = false

    // MARK: - Initializers

    // Athlete initializer (unchanged usage)
    init(userFirstName: String, userLastName: String, points: Int, cash: Int) {
        self.userFirstName = userFirstName
        self.userLastName  = userLastName
        self.kind = .athlete(points: points, cash: cash)
    }

    // Sponsor initializer (balance in header; compact controls padding)
    init(userFirstName: String, userLastName: String, balance: Double, compact: Bool = false, onTopUp: (() -> Void)? = nil) {
        self.userFirstName = userFirstName
        self.userLastName  = userLastName
        self.kind = .sponsor(balance: balance, compact: compact, onTopUp: onTopUp)
    }

    var body: some View {
        // compact only applies to sponsor mode
        let isCompactSponsor: Bool = {
            if case .sponsor(_, let compact, _) = kind { return compact }
            return false
        }()

        HStack(spacing: AppSpacing.md) {
            // Left: profile + first name with playful animation
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: AppSpacing.sm) {
                    // Animated profile icon
                    ZStack {
                        Circle()
                            .fill(AppGradients.accent)
                            .frame(width: 40, height: 40)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(color: AppColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hey,")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(userFirstName)
                            .font(AppTypography.title3.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .buttonStyle(.plain)

            // Right side varies by kind
            switch kind {
            case let .athlete(points, cash):
                Spacer() // push chips to the right edge
                
                VStack(spacing: AppSpacing.sm) {
                    // Points chip with star animation
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yellow)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: isAnimating)
                        
                        Text("\(points)")
                            .font(AppTypography.headline.weight(.bold))
                            .foregroundColor(.white)
                        
                        Text("pts")
                            .font(AppTypography.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(AppGradients.primary)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                    
                    // Cash chip with dollar animation
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Text("$\(cash)")
                            .font(AppTypography.headline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(AppGradients.accent)
                            .shadow(color: AppColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                }

            case let .sponsor(balance, _, onTopUp):
                Spacer() // push wallet card to the right edge

                // Modern wallet card with playful elements
                VStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Balance")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(String(format: "$%.2f", balance))
                                .font(isCompactSponsor ? AppTypography.title3.weight(.bold) : AppTypography.title2.weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        
                        Button(action: {
                            HapticManager.impact(style: .medium)
                            onTopUp?()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.accent)
                                .background(Circle().fill(.white))
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large)
                        .fill(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: AppShadows.medium.color, radius: AppShadows.medium.radius, x: AppShadows.medium.x, y: AppShadows.medium.y)
                )
                .frame(minWidth: 200, alignment: .trailing)
            }
        }
        // Compact sponsor trims padding so it fits cleanly in a tight row
        .padding(.horizontal, isCompactSponsor ? 0 : AppSpacing.md)
        .padding(.top, isCompactSponsor ? 0 : AppSpacing.lg)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Confetti Animation View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .animation(.easeOut(duration: particle.duration), value: particle.position)
            }
        }
        .onAppear {
            generateParticles()
        }
    }
    
    private func generateParticles() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
        
        for _ in 0..<30 {
            let particle = ConfettiParticle(
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 4...8),
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                opacity: Double.random(in: 0.6...1.0),
                duration: Double.random(in: 2.0...4.0)
            )
            particles.append(particle)
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    let opacity: Double
    let duration: Double
}

#Preview {
    VStack(spacing: 20) {
        WelcomeHeader(userFirstName: "Alex", userLastName: "Johnson", points: 1250, cash: 45)
        WelcomeHeader(userFirstName: "Coach", userLastName: "Smith", balance: 299.99, compact: false)
    }
    .padding()
    .background(Color(.systemBackground))
}
