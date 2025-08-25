//
//  SponUp2App.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/4/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UIKit

@main
struct SponUp2App: App {
    // MARK: – View-models
    @StateObject private var eventVM       = EventViewModel()
    @StateObject private var leaderboardVM = LeaderboardViewModel()
    @StateObject private var tierVM        = TierViewModel()
    @StateObject private var cartVM        = CartViewModel()
    @StateObject private var chaiAgent     = ChaiAgent()

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isForcedLoggedOut") private var isForcedLoggedOut = false

    init() {
        FirebaseApp.configure()
        configureTabBarAppearance()
        configureNavBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(eventVM)
                .environmentObject(leaderboardVM)
                .environmentObject(tierVM)
                .environmentObject(cartVM)
                .environmentObject(chaiAgent)
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
}

// MARK: – Appearance & Scene Helpers
private extension SponUp2App {
    func configureTabBarAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(AppColors.surface)

        let accent = UIColor(AppColors.accent)
        let secondary = UIColor(AppColors.textSecondary)

        let sel = tab.stackedLayoutAppearance.selected
        sel.iconColor = accent
        sel.titleTextAttributes = [
            .foregroundColor: accent,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]

        let nor = tab.stackedLayoutAppearance.normal
        nor.iconColor = secondary
        nor.titleTextAttributes = [
            .foregroundColor: secondary,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance   = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    func configureNavBarAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor            = UIColor(AppColors.accent)
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Don’t sign out. Just pause stuff if needed.
            tierVM.stopListening()
        case .active:
            if let uid = Auth.auth().currentUser?.uid {
                tierVM.startListening(uid: uid)
            }
        default:
            break
        }
    }
}

// MARK: – RootView
/// Switches between LandingView and MainTabView based on auth state.
/// Starts/stops TierViewModel points listener when auth changes.
struct RootView: View {
    @EnvironmentObject private var chaiAgent: ChaiAgent
    @EnvironmentObject private var tierVM: TierViewModel

    @State private var isLoggedIn = false
    @State private var userRole: UserRole?  = nil
    @State private var userFullName = ""
    @AppStorage("isForcedLoggedOut") private var isForcedLoggedOut = false
    @State private var coldStartDone = false

    var body: some View {
        Group {
            if isLoggedIn && !isForcedLoggedOut, let role = userRole {
                MainTabView(selectedRole: role, userFullName: userFullName)
            } else {
                LandingView(onSignInSuccess: handleSignIn)
            }
        }
        .transaction { $0.disablesAnimations = true }   // ← disable transition animations
        .onAppear {
            performColdStartLogout()
            listenAuthChanges()
        }
    }

    private func handleSignIn(role: UserRole, fullName: String) {
        DispatchQueue.main.async {
            // Set state with no animation
            withAnimation(.none) {
                chaiAgent.userName = fullName
                userRole          = role
                userFullName      = fullName
                isLoggedIn        = true
                isForcedLoggedOut = false
            }

            if let user = Auth.auth().currentUser {
                // Initialize root fields (incl. pointsTotal) + totals docs
                ensureTotalsDocsExist(
                    for: user.uid,
                    name: fullName,
                    email: user.email,
                    role: role
                )
                tierVM.startListening(uid: user.uid) // start live points listener
            }
        }
    }

    private func performColdStartLogout() {
        guard !coldStartDone else { return }
        coldStartDone = true
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
            withAnimation(.none) {                   // ← keep this quiet too
                isForcedLoggedOut = true
            }
            tierVM.stopListening()
        }
    }

    private func listenAuthChanges() {
        Auth.auth().addStateDidChangeListener { _, user in
            if isForcedLoggedOut {
                withAnimation(.none) {
                    isLoggedIn   = false
                    userRole     = nil
                    userFullName = ""
                }
                tierVM.stopListening()
                return
            }

            guard let user = user else {
                withAnimation(.none) {
                    isLoggedIn   = false
                    userRole     = nil
                    userFullName = ""
                }
                tierVM.stopListening()
                return
            }

            let uid = user.uid
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument { doc, _ in
                    if let data = doc?.data(),
                       let raw = data["role"] as? String,
                       let role = UserRole(rawValue: raw),
                       let name = data["fullName"] as? String {

                        withAnimation(.none) {
                            isLoggedIn   = true
                            userRole     = role
                            userFullName = name
                        }

                        // Ensure pointsTotal exists on the root doc as well
                        ensureTotalsDocsExist(
                            for: uid,
                            name: name,
                            email: user.email,
                            role: role
                        )
                        tierVM.startListening(uid: uid)
                    } else {
                        withAnimation(.none) {
                            isLoggedIn   = false
                            userRole     = nil
                            userFullName = ""
                        }
                        tierVM.stopListening()
                    }
                }
        }
    }

    // MARK: - Initialize user doc (root + totals) if missing (idempotent)
    private func ensureTotalsDocsExist(for uid: String,
                                       name: String? = nil,
                                       email: String? = nil,
                                       role: UserRole? = nil) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        // Root fields (merge so we don't overwrite anything)
        var root: [String: Any] = ["pointsTotal": 0]
        if let name  { root["fullName"] = name }
        if let email { root["email"]    = email }
        if let role  { root["role"]     = role.rawValue }
        userRef.setData(root, merge: true)

        // Subcollection docs
        let totals = userRef.collection("totals")
        totals.document("points").setData(["total": 0], merge: true)
        totals.document("cash").setData(["totalCents": 0, "currency": "USD"], merge: true)
    }
}


// MARK: – LandingView
struct LandingView: View {
    var onSignInSuccess: (UserRole, String) -> Void

    var body: some View {
        SignInView(onSignInSuccess: onSignInSuccess)
    }
}
