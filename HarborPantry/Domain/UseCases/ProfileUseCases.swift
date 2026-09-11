//
//  ProfileUseCases.swift
//  HarborPantry
//
//  Domain layer — household setup, onboarding state and data maintenance.
//

import Foundation

@MainActor
struct ProfileUseCases {
    private let profiles: ProfileRepository
    private let zones: StorageZoneRepository
    private let settings: SettingsRepository
    private let maintenance: DataMaintenanceRepository
    private let reminders: ReminderScheduling
    private let validator = ProfileValidator()
    private let zoneValidator = ZoneValidator()

    init(
        profiles: ProfileRepository,
        zones: StorageZoneRepository,
        settings: SettingsRepository,
        maintenance: DataMaintenanceRepository,
        reminders: ReminderScheduling
    ) {
        self.profiles = profiles
        self.zones = zones
        self.settings = settings
        self.maintenance = maintenance
        self.reminders = reminders
    }

    // MARK: - Profile

    func saveProfile(
        householdName: String,
        peopleCount: Int,
        defaultUnit: MeasurementUnit,
        currencyCode: String,
        dietaryNotes: String,
        weekStart: Weekday
    ) async throws {
        let name = try validator.validate(householdName: householdName, peopleCount: peopleCount)
        var profile = profiles.currentProfile()
        profile.householdName = name
        profile.peopleCount = peopleCount
        profile.defaultUnit = defaultUnit
        profile.currencyCode = currencyCode
        profile.dietaryNotes = dietaryNotes
        profile.weekStart = weekStart
        profile.isConfigured = true
        try await profiles.save(profile)
    }

    func deleteProfile() async throws {
        try await profiles.resetProfile()
    }

    // MARK: - Zones

    func addZone(name: String, type: StorageZoneType, capacityText: String, note: String) async throws {
        let validated = try zoneValidator.validate(
            name: name,
            type: type,
            capacityText: capacityText,
            existing: zones.zones(includeArchived: true),
            editingId: nil
        )
        try await zones.add(
            StorageZone(name: validated.name, type: type, capacity: validated.capacity, note: note)
        )
    }

    func updateZone(
        _ zone: StorageZone,
        name: String,
        type: StorageZoneType,
        capacityText: String,
        note: String
    ) async throws {
        let validated = try zoneValidator.validate(
            name: name,
            type: type,
            capacityText: capacityText,
            existing: zones.zones(includeArchived: true),
            editingId: zone.id
        )
        var updated = zone
        updated.name = validated.name
        updated.type = type
        updated.capacity = validated.capacity
        updated.note = note
        try await zones.update(updated)
    }

    func deleteZone(id: UUID) async throws {
        try await zones.delete(id: id)
    }

    func setZoneArchived(_ archived: Bool, id: UUID) async throws {
        guard var zone = zones.zone(id: id) else {
            throw DomainError.notFound("That zone no longer exists.")
        }
        zone.isArchived = archived
        try await zones.update(zone)
    }

    // MARK: - Onboarding and settings

    func completeOnboarding(remindersEnabled: Bool) async throws {
        var current = settings.settings()
        current.hasCompletedOnboarding = true
        current.remindersEnabled = remindersEnabled
        try await settings.save(current)
    }

    /// Asks the system for permission. A refusal is stored and respected, and
    /// never stops the user from using the app.
    @discardableResult
    func requestReminderPermission() async throws -> Bool {
        let granted = await reminders.requestAuthorization()
        var current = settings.settings()
        current.remindersEnabled = granted
        try await settings.save(current)
        return granted
    }

    func setRemindersEnabled(_ enabled: Bool) async throws {
        var current = settings.settings()
        if enabled {
            // Ask only if the system has not already answered.
            var granted = await reminders.authorizationGranted()
            if !granted {
                granted = await reminders.requestAuthorization()
            }
            current.remindersEnabled = granted
        } else {
            current.remindersEnabled = false
            await reminders.cancelAll()
        }
        try await settings.save(current)
    }

    func setHomeFilter(_ filter: HomeFilter) async throws {
        var current = settings.settings()
        current.homeFilter = filter
        try await settings.save(current)
    }

    // MARK: - Data maintenance

    func exportData() async throws -> Data {
        try await maintenance.exportSnapshotData()
    }

    func validateImport(_ data: Data) async throws -> ImportPreview {
        try await maintenance.validateImport(data)
    }

    func applyImport(_ data: Data) async throws {
        try await maintenance.applyImport(data)
    }

    func clearHistory() async throws {
        try await maintenance.clearHistory()
    }

    func deleteAllData() async throws {
        await reminders.cancelAll()
        try await maintenance.deleteAllData()
    }
}
