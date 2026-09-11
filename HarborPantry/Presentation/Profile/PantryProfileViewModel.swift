//
//  PantryProfileViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class PantryProfileViewModel: ObservableObject {
    @Published var householdName: String = ""
    @Published var peopleCount: Int = 2
    @Published var defaultUnit: MeasurementUnit = .piece
    @Published var currencyCode: String = "USD"
    @Published var dietaryNotes: String = ""
    @Published var weekStart: Weekday = .monday

    @Published private(set) var zones: [StorageZone] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var deleteConfirmationText: String = ""

    private let profileUseCases: ProfileUseCases
    private let profileRepository: ProfileRepository
    private let zoneRepository: StorageZoneRepository
    private var cancellables = Set<AnyCancellable>()

    /// The word the user must type before the profile is reset.
    let deleteKeyword = "DELETE"

    convenience init(dependencies: AppDependencies) {
        self.init(
            profileUseCases: dependencies.profileUseCases,
            profileRepository: dependencies.profileRepository,
            zoneRepository: dependencies.zoneRepository
        )
    }

    init(
        profileUseCases: ProfileUseCases,
        profileRepository: ProfileRepository,
        zoneRepository: StorageZoneRepository
    ) {
        self.profileUseCases = profileUseCases
        self.profileRepository = profileRepository
        self.zoneRepository = zoneRepository

        let profile = profileRepository.currentProfile()
        householdName = profile.householdName
        peopleCount = profile.peopleCount
        defaultUnit = profile.defaultUnit
        currencyCode = profile.currencyCode
        dietaryNotes = profile.dietaryNotes
        weekStart = profile.weekStart

        zoneRepository.zonesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadZones()
            }
            .store(in: &cancellables)
        reloadZones()
    }

    var canDelete: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == deleteKeyword
    }

    var currencyOptions: [CurrencyOption] { CurrencyOption.all }

    func reloadZones() {
        zones = zoneRepository.zones(includeArchived: false)
    }

    @discardableResult
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await profileUseCases.saveProfile(
                householdName: householdName,
                peopleCount: peopleCount,
                defaultUnit: defaultUnit,
                currencyCode: currencyCode,
                dietaryNotes: dietaryNotes,
                weekStart: weekStart
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addZone(name: String, type: StorageZoneType, capacity: String, note: String) async -> Bool {
        do {
            try await profileUseCases.addZone(
                name: name,
                type: type,
                capacityText: capacity,
                note: note
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteProfile() async -> Bool {
        guard canDelete else { return false }
        do {
            try await profileUseCases.deleteProfile()
            householdName = ""
            peopleCount = 2
            dietaryNotes = ""
            deleteConfirmationText = ""
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
