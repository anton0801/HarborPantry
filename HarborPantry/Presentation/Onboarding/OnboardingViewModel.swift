//
//  OnboardingViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Finish {
        /// "Get Started" — continue into the household setup.
        case setUpProfile
        /// "Skip" — go straight to an empty Home.
        case skip
    }

    struct Page: Identifiable {
        let id: Int
        let title: String
        let message: String
        let illustration: HarborIllustration
    }

    let pages: [Page] = [
        Page(
            id: 0,
            title: "Fresh Food in One Place",
            message: "Add anything you keep at home and give it a spot in the fridge, the freezer or a cupboard. Harbor Pantry keeps the count, you keep the dates.",
            illustration: .onboardingInventory
        ),
        Page(
            id: 1,
            title: "Plan Meals and Portions",
            message: "Build dishes from what you already have. Change the number of people at the table and every ingredient is recalculated with you.",
            illustration: .onboardingMeals
        ),
        Page(
            id: 2,
            title: "Shop Only What You Need",
            message: "Missing ingredients collect into one shopping list, and a prep timeline lines up thawing and cooking before the meal.",
            illustration: .onboardingShopping
        )
    ]

    @Published private(set) var index: Int = 0
    @Published var remindersEnabled: Bool = false
    /// Blocks a second tap while a page transition is running.
    @Published private(set) var isTransitioning: Bool = false
    @Published var permissionMessage: String?

    private let profileUseCases: ProfileUseCases

    init(profileUseCases: ProfileUseCases) {
        self.profileUseCases = profileUseCases
    }

    var currentPage: Page { pages[index] }
    var isLastPage: Bool { index == pages.count - 1 }
    var isFirstPage: Bool { index == 0 }
    var progressText: String { "\(index + 1)/\(pages.count)" }

    func next() {
        guard !isTransitioning, !isLastPage else { return }
        beginTransition()
        withAnimation(.easeInOut(duration: 0.28)) {
            index += 1
        }
    }

    func back() {
        guard !isTransitioning, !isFirstPage else { return }
        beginTransition()
        withAnimation(.easeInOut(duration: 0.28)) {
            index -= 1
        }
    }

    private func beginTransition() {
        isTransitioning = true
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            isTransitioning = false
        }
    }

    /// Asks the system for notification permission. Declining is recorded and
    /// never blocks anything else in the app.
    func toggleReminders(_ enabled: Bool) async {
        guard enabled else {
            remindersEnabled = false
            permissionMessage = nil
            return
        }
        do {
            let granted = try await profileUseCases.requestReminderPermission()
            remindersEnabled = granted
            permissionMessage = granted
                ? nil
                : "Notifications are off for Harbor Pantry. You can turn them on later in Settings — everything else works either way."
        } catch {
            remindersEnabled = false
            permissionMessage = "Reminders could not be enabled right now. The rest of the app is unaffected."
        }
    }

    func finish(_ kind: Finish) async {
        try? await profileUseCases.completeOnboarding(remindersEnabled: remindersEnabled)
    }
}
