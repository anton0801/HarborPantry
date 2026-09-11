//
//  HomeViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var dashboard: HomeDashboard = .empty
    @Published private(set) var profile: PantryProfile = PantryProfile()
    @Published var filter: HomeFilter = .today {
        didSet {
            guard oldValue != filter else { return }
            refresh()
            Task { try? await profileUseCases.setHomeFilter(filter) }
        }
    }
    @Published private(set) var loadState: StoreLoadState = .idle

    private let homeUseCases: HomeUseCases
    private let profileUseCases: ProfileUseCases
    private let store: PantryStore
    private let freshness: FreshnessService
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            homeUseCases: dependencies.homeUseCases,
            profileUseCases: dependencies.profileUseCases,
            settingsRepository: dependencies.settingsRepository,
            profileRepository: dependencies.profileRepository,
            store: dependencies.store,
            freshness: dependencies.freshnessService
        )
    }

    init(
        homeUseCases: HomeUseCases,
        profileUseCases: ProfileUseCases,
        settingsRepository: SettingsRepository,
        profileRepository: ProfileRepository,
        store: PantryStore,
        freshness: FreshnessService
    ) {
        self.homeUseCases = homeUseCases
        self.profileUseCases = profileUseCases
        self.store = store
        self.freshness = freshness

        self.filter = settingsRepository.settings().homeFilter
        self.profile = profileRepository.currentProfile()

        // Any change anywhere in the pantry rebuilds the dashboard.
        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        store.$loadState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.loadState = state }
            .store(in: &cancellables)

        profileRepository.profilePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.profile = value }
            .store(in: &cancellables)

        refresh()
    }

    func refresh() {
        dashboard = homeUseCases.dashboard(filter: filter)
    }

    func daysRemainingText(for product: Product) -> String {
        guard let days = freshness.daysRemaining(for: product) else { return "No date" }
        return HarborFormat.relativeDays(days)
    }

    func bucket(for product: Product) -> FreshnessBucket {
        freshness.bucket(for: product)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
