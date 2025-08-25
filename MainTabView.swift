import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var eventVM: EventViewModel
    @EnvironmentObject var tierVM: TierViewModel

    let selectedRole: UserRole
    let userFullName: String

    @State private var selectedTab = 0
    @State private var isChatOpen = false  // you can also remove this if you no longer use it here

    init(selectedRole: UserRole, userFullName: String = "") {
        self.selectedRole = selectedRole
        self.userFullName = userFullName
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // ─── HOME ───────────────────────────────
            NavigationStack {
                if selectedRole == .athlete {
                    AthleteHomeView(userFullName: userFullName)
                } else {
                    SponsorHomeView(userFullName: userFullName)
                }
                // ← NO toolbar here anymore
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            // ─── ATHLETE TABS ────────────────────────
            if selectedRole == .athlete {
                NavigationStack {
                    MyChallengesView()
                }
                .tabItem {
                    Image(systemName: "checkmark.square")
                    Text("My Training")
                }
                .tag(1)

                NavigationStack {
                    EventsView()
                }
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Events")
                }
                .tag(2)

                NavigationStack {
                    WalletView()
                }
                .tabItem {
                    Image(systemName: "wallet.pass")
                    Text("Wallet")
                }
                .tag(3)

                

            // ─── SPONSOR TABS ────────────────────────
            } else {
                NavigationStack {
                    SponsorAthleteView()
                }
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Athletes")
                }
                .tag(1)

                NavigationStack {
                    WalletView()
                }
                .tabItem {
                    Image(systemName: "wallet.pass")
                    Text("Wallet")
                }
                .tag(2)

                NavigationStack {
                    SponsorProfileView()
                }
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
                .tag(3)
            }
        }
        .accentColor(AppColors.accent)
        .onAppear {
            // Configure tab bar appearance for modern look
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.surface)
            
            // Selected tab styling
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.accent)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.accent),
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
            ]
            
            // Normal tab styling
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.textSecondary),
                .font: UIFont.systemFont(ofSize: 12, weight: .medium)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
