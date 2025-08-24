import SwiftUI

// MARK: - Modern Onboarding Experience
/// A delightful onboarding experience designed for youth athletes
/// following Apple's design guidelines with playful animations

struct ModernOnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var animateContent = false
    
    private let onboardingPages = [
        OnboardingPage(
            title: "Welcome to SponUp!",
            subtitle: "Your journey to becoming a champion starts here",
            description: "Connect with sponsors, complete challenges, and earn rewards while improving your game.",
            icon: "star.circle.fill",
            color: AppColors.accent,
            animation: "welcome"
        ),
        OnboardingPage(
            title: "Complete Challenges",
            subtitle: "Train smarter, not harder",
            description: "Take on exciting challenges designed by coaches and sponsors to level up your skills.",
            icon: "target",
            color: AppColors.primary,
            animation: "challenges"
        ),
        OnboardingPage(
            title: "Earn Rewards",
            subtitle: "Get rewarded for your hard work",
            description: "Earn points, cash prizes, and exclusive gear from top sports brands and sponsors.",
            icon: "gift.fill",
            color: AppColors.success,
            animation: "rewards"
        ),
        OnboardingPage(
            title: "Connect & Grow",
            subtitle: "Build your network",
            description: "Connect with other athletes, coaches, and sponsors to grow your career in sports.",
            icon: "person.3.sequence.fill",
            color: AppColors.warning,
            animation: "network"
        )
    ]
    
    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: onboardingPages[index],
                            isActive: currentPage == index
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentPage)
                
                // Bottom controls
                VStack(spacing: AppSpacing.lg) {
                    // Page indicators
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                                .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentPage)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: AppSpacing.md) {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentPage -= 1
                                }
                                HapticManager.impact(style: .light)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        
                        Spacer()
                        
                        Button(currentPage == onboardingPages.count - 1 ? "Get Started" : "Next") {
                            if currentPage == onboardingPages.count - 1 {
                                completeOnboarding()
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                                HapticManager.impact(style: .light)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .onAppear {
            animateContent = true
        }
    }
    
    private func completeOnboarding() {
        HapticManager.notification(type: .success)
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let animation: String
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    
    @State private var animateIcon = false
    @State private var animateText = false
    
    var body: some View {
        VStack(spacing: AppSpacing.xxl) {
            Spacer()
            
            // Icon with animation
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateIcon ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateIcon)
                
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(page.color)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateIcon)
            }
            .onAppear {
                animateIcon = true
            }
            
            // Text content
            VStack(spacing: AppSpacing.lg) {
                Text(page.title)
                    .font(AppTypography.largeTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                
                Text(page.subtitle)
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                
                Text(page.description)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
            }
            .padding(.horizontal, AppSpacing.xl)
            
            Spacer()
        }
        .onAppear {
            if isActive {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                    animateText = true
                }
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                animateText = false
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                    animateText = true
                }
            }
        }
    }
}

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {
    @Published var isOnboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        }
    }
    
    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    }
    
    func resetOnboarding() {
        isOnboardingComplete = false
    }
}

// MARK: - Preview
#Preview {
    ModernOnboardingView(isOnboardingComplete: .constant(false))
}
