//
//  AppRootView.swift
//  HarborPantry
//
//  Presentation layer — decides between onboarding and the main app, and
//  reflects the store's load state.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    @State private var hasCompletedOnboarding: Bool?
    @State private var showProfileSetup = false

    var body: some View {
        Group {
            switch resolvedState {
            case .booting:
                bootScreen
            case .onboarding:
                OnboardingView(profileUseCases: dependencies.profileUseCases) { finish in
                    hasCompletedOnboarding = true
                    showProfileSetup = (finish == .setUpProfile)
                }
                .transition(.opacity)
            case .main:
                MainTabView(showProfileSetup: $showProfileSetup)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: resolvedState)
        .onReceive(dependencies.store.$loadState) { state in
            // Wait for the store to finish loading before reading the flag —
            // the in-memory snapshot is still empty while `.idle`/`.loading`,
            // and latching there would show onboarding on every launch.
            switch state {
            case .idle, .loading:
                break
            case .loaded, .cached, .failed:
                if hasCompletedOnboarding == nil {
                    hasCompletedOnboarding = dependencies.store.snapshot.settings.hasCompletedOnboarding
                }
            }
        }
    }

    private enum RootState: Equatable {
        case booting
        case onboarding
        case main
    }

    private var resolvedState: RootState {
        guard let completed = hasCompletedOnboarding else { return .booting }
        return completed ? .main : .onboarding
    }

    private var bootScreen: some View {
        ZStack {
            HarborGradient.deepOcean.ignoresSafeArea()
            VStack(spacing: HarborMetrics.spacingL) {
                HarborIllustrationView(illustration: .homeFisherman)
                    .frame(width: 180)
                Text("Harbor Pantry")
                    .font(HarborFont.display(30))
                    .foregroundColor(.white)
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
