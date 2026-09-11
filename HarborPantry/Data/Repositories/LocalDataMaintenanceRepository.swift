//
//  LocalDataMaintenanceRepository.swift
//  HarborPantry
//
//  Data layer — export, validated import, and destructive clean-up.
//

import Foundation

@MainActor
final class LocalDataMaintenanceRepository: DataMaintenanceRepository {
    private let store: PantryStore
    private let photoStore: PhotoStoring

    init(store: PantryStore, photoStore: PhotoStoring) {
        self.store = store
        self.photoStore = photoStore
    }

    func exportSnapshotData() async throws -> Data {
        try await store.exportData()
    }

    /// Reads the file and reports what *would* be imported. Nothing is written
    /// here — the user always sees this preview first.
    func validateImport(_ data: Data) async throws -> ImportPreview {
        let snapshot = try await store.decodeSnapshot(from: data)

        var counts = ImportPreview.Counts()
        counts.products = snapshot.products.count
        counts.zones = snapshot.zones.count
        counts.dishes = snapshot.dishes.count
        counts.mealEntries = snapshot.mealEntries.count
        counts.shoppingItems = snapshot.shoppingItems.count
        counts.prepTasks = snapshot.prepTasks.count
        counts.leftovers = snapshot.leftovers.count
        counts.historyEntries = snapshot.history.count

        var issues: [String] = []

        if snapshot.schemaVersion > PantrySnapshot.currentSchemaVersion {
            issues.append(
                "The file was written by a newer version of Harbor Pantry (schema \(snapshot.schemaVersion))."
            )
        }

        if snapshot.zones.isEmpty && !snapshot.products.isEmpty {
            issues.append("The file has products but no storage zones.")
        }

        let zoneIds = Set(snapshot.zones.map(\.id))
        let orphanProducts = snapshot.products.filter { !zoneIds.contains($0.zoneId) }
        if !orphanProducts.isEmpty {
            issues.append("\(orphanProducts.count) product(s) point to a storage zone that is not in the file.")
        }

        let duplicateZoneNames = Dictionary(grouping: snapshot.zones, by: \.normalizedName)
            .filter { $0.value.count > 1 }
        if !duplicateZoneNames.isEmpty {
            issues.append("\(duplicateZoneNames.count) storage zone name(s) appear more than once.")
        }

        let dishIds = Set(snapshot.dishes.map(\.id))
        let orphanMeals = snapshot.mealEntries.filter { !dishIds.contains($0.dishId) }
        if !orphanMeals.isEmpty {
            issues.append("\(orphanMeals.count) planned meal(s) reference a dish that is not in the file.")
        }

        if snapshot.products.contains(where: { $0.quantity <= 0 }) {
            issues.append("Some products have a quantity of zero or less.")
        }

        return ImportPreview(
            counts: counts,
            issues: issues,
            exportedAt: snapshot.exportedAt,
            schemaVersion: snapshot.schemaVersion
        )
    }

    func applyImport(_ data: Data) async throws {
        let snapshot = try await store.decodeSnapshot(from: data)
        let preview = try await validateImport(data)
        guard preview.isValid else {
            throw DomainError.importFailed(
                "Fix the reported problems before importing, or choose a different file."
            )
        }
        var imported = snapshot
        // Keep this device's own onboarding state; the rest comes from the file.
        imported.settings.hasCompletedOnboarding = store.snapshot.settings.hasCompletedOnboarding
        try await store.replace(with: imported)
    }

    func clearHistory() async throws {
        try await store.mutate { $0.history.removeAll() }
    }

    func deleteAllData() async throws {
        let photoNames = store.snapshot.products.compactMap(\.photoFileName)
        try await store.wipe()
        for name in photoNames {
            photoStore.delete(named: name)
        }
    }
}
