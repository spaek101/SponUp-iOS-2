import SwiftUI

// MARK: - Modern Toast Notification System
/// A modern, accessible toast notification system following Apple's design guidelines
/// with playful animations and youth-friendly styling

struct ModernToastView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var offset: CGFloat = 100
    @State private var opacity: Double = 0
    
    enum ToastType {
        case success, warning, error, info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            case .info: return AppColors.primary
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .success: return AppColors.success.opacity(0.1)
            case .warning: return AppColors.warning.opacity(0.1)
            case .error: return AppColors.error.opacity(0.1)
            case .info: return AppColors.primary.opacity(0.1)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon with animation
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(type.color)
                .scaleEffect(isVisible ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isVisible)
            
            // Message
            Text(message)
                .font(AppTypography.body.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Dismiss button
            Button(action: {
                dismissToast()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .fill(type.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large)
                        .stroke(type.color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadows.large.color, radius: AppShadows.large.radius, x: AppShadows.large.x, y: AppShadows.large.y)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            showToast()
        }
    }
    
    private func showToast() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            offset = 0
            opacity = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isVisible = true
        }
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissToast()
        }
    }
    
    private func dismissToast() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            offset = 100
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDismiss()
        }
    }
}

// MARK: - Toast Manager
class ToastManager: ObservableObject {
    @Published var currentToast: ToastData?
    
    struct ToastData: Identifiable {
        let id = UUID()
        let message: String
        let type: ModernToastView.ToastType
        let duration: TimeInterval
    }
    
    func showToast(_ message: String, type: ModernToastView.ToastType = .info, duration: TimeInterval = 4.0) {
        currentToast = ToastData(message: message, type: type, duration: duration)
    }
    
    func dismissToast() {
        currentToast = nil
    }
}

// MARK: - Toast Container View
struct ToastContainerView: View {
    @ObservedObject var toastManager: ToastManager
    
    var body: some View {
        ZStack {
            if let toast = toastManager.currentToast {
                VStack {
                    Spacer()
                    
                    ModernToastView(
                        message: toast.message,
                        type: toast.type
                    ) {
                        toastManager.dismissToast()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, 100) // Account for tab bar
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toastManager.currentToast != nil)
            }
        }
    }
}

// MARK: - View Extension for Easy Toast Usage
extension View {
    func showToast(_ message: String, type: ModernToastView.ToastType = .info, duration: TimeInterval = 4.0) {
        // This would be used with the ToastManager in a real implementation
        // For now, it's a placeholder for the API design
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ModernToastView(
            message: "Great job! You've earned 100 points!",
            type: .success
        ) {}
        
        ModernToastView(
            message: "Warning: You're approaching your daily limit",
            type: .warning
        ) {}
        
        ModernToastView(
            message: "Oops! Something went wrong. Please try again.",
            type: .error
        ) {}
        
        ModernToastView(
            message: "New challenge available in your area!",
            type: .info
        ) {}
    }
    .padding()
    .background(Color(.systemBackground))
}
