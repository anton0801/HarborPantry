//
//  Repositories.swift
//  HarborPantry
//
//  Domain layer — storage boundaries. The domain never learns how or where
//  data is persisted; the Data layer supplies these.
//

import Foundation
import Combine

@MainActor
protocol ProfileRepository: AnyObject {
    var profilePublisher: AnyPublisher<PantryProfile, Never> { get }
    func currentProfile() -> PantryProfile
    func save(_ profile: PantryProfile) async throws
    func resetProfile() async throws
}

@MainActor
protocol StorageZoneRepository: AnyObject {
    var zonesPublisher: AnyPublisher<[StorageZone], Never> { get }
    func zones(includeArchived: Bool) -> [StorageZone]
    func zone(id: UUID) -> StorageZone?
    func add(_ zone: StorageZone) async throws
    func update(_ zone: StorageZone) async throws
    func delete(id: UUID) async throws
    func replaceAll(_ zones: [StorageZone]) async throws
}

@MainActor
protocol ProductRepository: AnyObject {
    var productsPublisher: AnyPublisher<[Product], Never> { get }
    func products(includeArchived: Bool) -> [Product]
    func product(id: UUID) -> Product?
    func add(_ product: Product) async throws
    func update(_ product: Product) async throws
    func delete(ids: [UUID]) async throws
    func upsert(_ products: [Product]) async throws
}

@MainActor
protocol HistoryRepository: AnyObject {
    var historyPublisher: AnyPublisher<[ProductHistoryEntry], Never> { get }
    func entries(limit: Int?) -> [ProductHistoryEntry]
    func entries(forProduct id: UUID) -> [ProductHistoryEntry]
    func record(_ entry: ProductHistoryEntry) async throws
    func remove(id: UUID) async throws
    func clearAll() async throws
}

@MainActor
protocol DishRepository: AnyObject {
    var dishesPublisher: AnyPublisher<[Dish], Never> { get }
    func dishes(includeArchived: Bool) -> [Dish]
    func dish(id: UUID) -> Dish?
    func add(_ dish: Dish) async throws
    func update(_ dish: Dish) async throws
    func delete(id: UUID) async throws
}

@MainActor
protocol MealPlanRepository: AnyObject {
    var entriesPublisher: AnyPublisher<[MealPlanEntry], Never> { get }
    func entries() -> [MealPlanEntry]
    func entries(on day: Date) -> [MealPlanEntry]
    func entry(id: UUID) -> MealPlanEntry?
    func add(_ entry: MealPlanEntry) async throws
    func update(_ entry: MealPlanEntry) async throws
    func delete(ids: [UUID]) async throws
}

@MainActor
protocol ShoppingRepository: AnyObject {
    var itemsPublisher: AnyPublisher<[ShoppingItem], Never> { get }
    func items() -> [ShoppingItem]
    func item(id: UUID) -> ShoppingItem?
    func add(_ item: ShoppingItem) async throws
    func update(_ item: ShoppingItem) async throws
    func upsert(_ items: [ShoppingItem]) async throws
    func delete(ids: [UUID]) async throws
}

@MainActor
protocol PrepRepository: AnyObject {
    var tasksPublisher: AnyPublisher<[PrepTask], Never> { get }
    func tasks() -> [PrepTask]
    func task(id: UUID) -> PrepTask?
    func add(_ task: PrepTask) async throws
    func update(_ task: PrepTask) async throws
    func delete(id: UUID) async throws
}

@MainActor
protocol LeftoverRepository: AnyObject {
    var leftoversPublisher: AnyPublisher<[Leftover], Never> { get }
    func leftovers() -> [Leftover]
    func leftover(id: UUID) -> Leftover?
    func add(_ leftover: Leftover) async throws
    func update(_ leftover: Leftover) async throws
    func delete(id: UUID) async throws
}

@MainActor
protocol SettingsRepository: AnyObject {
    var settingsPublisher: AnyPublisher<AppSettings, Never> { get }
    func settings() -> AppSettings
    func save(_ settings: AppSettings) async throws
}

/// Bulk operations that touch every store at once.
@MainActor
protocol DataMaintenanceRepository: AnyObject {
    func exportSnapshotData() async throws -> Data
    func validateImport(_ data: Data) async throws -> ImportPreview
    func applyImport(_ data: Data) async throws
    func clearHistory() async throws
    func deleteAllData() async throws
}

/// The result of inspecting an import file before anything is written.
struct ImportPreview: Hashable {
    struct Counts: Hashable {
        var products: Int = 0
        var zones: Int = 0
        var dishes: Int = 0
        var mealEntries: Int = 0
        var shoppingItems: Int = 0
        var prepTasks: Int = 0
        var leftovers: Int = 0
        var historyEntries: Int = 0
    }

    let counts: Counts
    let issues: [String]
    let exportedAt: Date?
    let schemaVersion: Int

    var isValid: Bool { issues.isEmpty }

    var totalRecords: Int {
        counts.products + counts.zones + counts.dishes + counts.mealEntries
            + counts.shoppingItems + counts.prepTasks + counts.leftovers + counts.historyEntries
    }
}

/// Local notification scheduling. Refusing permission never blocks the app.
@MainActor
protocol ReminderScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func authorizationGranted() async -> Bool
    func schedule(_ reminder: PantryReminder) async throws
    func cancel(id: UUID) async
    func cancelAll() async
}

/// Storage for user-taken product photos.
@MainActor
protocol PhotoStoring: AnyObject {
    func save(imageData: Data) throws -> String
    func loadData(named fileName: String) -> Data?
    func delete(named fileName: String)
}
