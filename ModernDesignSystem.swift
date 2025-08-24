import SwiftUI

// MARK: - Modern Design System for SponUp
/// A comprehensive design system following Apple's latest guidelines
/// with playful, youth-friendly components for athletes

// MARK: - Color Palette
struct AppColors {
    static let primary = Color("AppTheme")
    static let accent = Color("AppAccent")
    static let surface = Color("AppSurface")
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
}

// MARK: - Typography Scale
struct AppTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
    static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .rounded)
}

// MARK: - Spacing Scale
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius Scale
struct AppCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
}

// MARK: - Shadow System
struct AppShadows {
    static let small = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    static let medium = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    static let large = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Modern Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(AppColors.accent)
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(AppColors.accent, lineWidth: 2)
                    .background(Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Modern Card Style
struct ModernCardStyle: ViewModifier {
    let color: Color
    
    init(color: Color = AppColors.surface) {
        self.color = color
    }
    
    func body(content: Content) -> some View {
        content
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            .shadow(color: AppShadows.medium.color, radius: AppShadows.medium.radius, x: AppShadows.medium.x, y: AppShadows.medium.y)
    }
}

// MARK: - Gradient Backgrounds
struct AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accent = LinearGradient(
        colors: [AppColors.accent, AppColors.accent.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let surface = LinearGradient(
        colors: [AppColors.surface, AppColors.surface.opacity(0.9)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Animated Background
struct AnimatedBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            AppGradients.primary
                .hueRotation(.degrees(animateGradient ? 45 : 0))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: animateGradient)
            
            // Floating particles for playfulness
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 4...12))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...8))
                        .repeatForever(autoreverses: true),
                        value: animateGradient
                    )
            }
        }
        .onAppear {
            animateGradient.toggle()
        }
    }
}

// MARK: - Modern Tab Style
struct ModernTabStyle: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .font(AppTypography.footnote.weight(.semibold))
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(isSelected ? AppColors.accent : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(isSelected ? Color.clear : AppColors.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Progress Indicator
struct ModernProgressIndicator: View {
    let progress: Double
    let color: Color
    
    init(progress: Double, color: Color = AppColors.accent) {
        self.progress = progress
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Badge Component
struct ModernBadge: View {
    let text: String
    let color: Color
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return AppTypography.caption2
            case .medium: return AppTypography.caption
            case .large: return AppTypography.footnote
            }
        }
    }
    
    init(text: String, color: Color = AppColors.accent, size: BadgeSize = .medium) {
        self.text = text
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(size.fontSize.weight(.semibold))
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            )
    }
}

// MARK: - View Extensions
extension View {
    func modernCard(color: Color = AppColors.surface) -> some View {
        modifier(ModernCardStyle(color: color))
    }
    
    func modernTab(isSelected: Bool) -> some View {
        modifier(ModernTabStyle(isSelected: isSelected))
    }
    
    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Haptic Feedback
struct HapticManager {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }
}
