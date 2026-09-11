//
//  LocalRepositories.swift
//  HarborPantry
//
//  Data layer — repository implementations backed by `PantryStore`.
//

import Foundation
import Combine

// MARK: - Profile

@MainActor
final class LocalProfileRepository: ProfileRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var profilePublisher: AnyPublisher<PantryProfile, Never> {
        store.$snapshot.map(\.profile).removeDuplicates().eraseToAnyPublisher()
    }

    func currentProfile() -> PantryProfile { store.snapshot.profile }

    func save(_ profile: PantryProfile) async throws {
        var updated = profile
        updated.updatedAt = Date()
        try await store.mutate { $0.profile = updated }
    }

    func resetProfile() async throws {
        try await store.mutate { $0.profile = PantryProfile() }
    }
}

// MARK: - Storage zones

@MainActor
final class LocalStorageZoneRepository: StorageZoneRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var zonesPublisher: AnyPublisher<[StorageZone], Never> {
        store.$snapshot.map(\.zones).removeDuplicates().eraseToAnyPublisher()
    }

    func zones(includeArchived: Bool) -> [StorageZone] {
        store.snapshot.zones
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    func zone(id: UUID) -> StorageZone? {
        store.snapshot.zones.first { $0.id == id }
    }

    func add(_ zone: StorageZone) async throws {
        try await store.mutate { snapshot in
            guard !snapshot.zones.contains(where: { $0.normalizedName == zone.normalizedName }) else {
                throw DomainError.conflict("A zone named “\(zone.name)” already exists.")
            }
            var new = zone
            new.sortIndex = (snapshot.zones.map(\.sortIndex).max() ?? -1) + 1
            snapshot.zones.append(new)
        }
    }

    func update(_ zone: StorageZone) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.zones.firstIndex(where: { $0.id == zone.id }) else {
                throw DomainError.notFound("That storage zone no longer exists.")
            }
            let clash = snapshot.zones.contains {
                $0.id != zone.id && $0.normalizedName == zone.normalizedName
            }
            guard !clash else {
                throw DomainError.conflict("A zone named “\(zone.name)” already exists.")
            }
            snapshot.zones[index] = zone
        }
    }

    func delete(id: UUID) async throws {
        try await store.mutate { snapshot in
            // A zone that still holds products cannot be removed; the user has
            // to move its contents first.
            let occupants = snapshot.products.filter { $0.zoneId == id && !$0.isArchived }
            guard occupants.isEmpty else {
                throw DomainError.conflict(
                    "Move the \(occupants.count) product\(occupants.count == 1 ? "" : "s") out of this zone first."
                )
            }
            snapshot.zones.removeAll { $0.id == id }
        }
    }

    func replaceAll(_ zones: [StorageZone]) async throws {
        try await store.mutate { $0.zones = zones }
    }
}

// MARK: - Products

@MainActor
final class LocalProductRepository: ProductRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var productsPublisher: AnyPublisher<[Product], Never> {
        store.$snapshot.map(\.products).removeDuplicates().eraseToAnyPublisher()
    }

    func products(includeArchived: Bool) -> [Product] {
        store.snapshot.products.filter { includeArchived || !$0.isArchived }
    }

    func product(id: UUID) -> Product? {
        store.snapshot.products.first { $0.id == id }
    }

    func add(_ product: Product) async throws {
        try await store.mutate { $0.products.append(product) }
    }

    func update(_ product: Product) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.products.firstIndex(where: { $0.id == product.id }) else {
                throw DomainError.notFound("That product no longer exists.")
            }
            var updated = product
            updated.updatedAt = Date()
            snapshot.products[index] = updated
        }
    }

    func delete(ids: [UUID]) async throws {
        let idSet = Set(ids)
        try await store.mutate { snapshot in
            snapshot.products.removeAll { idSet.contains($0.id) }
            // Drop the inventory link from dishes but keep the ingredient row:
            // the dish still needs that ingredient, it just no longer points at
            // a product that is gone.
            for dishIndex in snapshot.dishes.indices {
                for ingredientIndex in snapshot.dishes[dishIndex].ingredients.indices {
                    if let linked = snapshot.dishes[dishIndex].ingredients[ingredientIndex].linkedProductId,
                       idSet.contains(linked) {
                        snapshot.dishes[dishIndex].ingredients[ingredientIndex].linkedProductId = nil
                    }
                }
            }
            for taskIndex in snapshot.prepTasks.indices {
                if let linked = snapshot.prepTasks[taskIndex].linkedProductId, idSet.contains(linked) {
                    snapshot.prepTasks[taskIndex].linkedProductId = nil
                }
            }
        }
    }

    func upsert(_ products: [Product]) async throws {
        try await store.mutate { snapshot in
            for product in products {
                if let index = snapshot.products.firstIndex(where: { $0.id == product.id }) {
                    snapshot.products[index] = product
                } else {
                    snapshot.products.append(product)
                }
            }
        }
    }
}

// MARK: - History

@MainActor
final class LocalHistoryRepository: HistoryRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var historyPublisher: AnyPublisher<[ProductHistoryEntry], Never> {
        store.$snapshot.map(\.history).removeDuplicates().eraseToAnyPublisher()
    }

    func entries(limit: Int?) -> [ProductHistoryEntry] {
        let sorted = store.snapshot.history.sorted { $0.createdAt > $1.createdAt }
        guard let limit = limit else { return sorted }
        return Array(sorted.prefix(limit))
    }

    func entries(forProduct id: UUID) -> [ProductHistoryEntry] {
        store.snapshot.history
            .filter { $0.productId == id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func record(_ entry: ProductHistoryEntry) async throws {
        try await store.mutate { $0.history.append(entry) }
    }

    func remove(id: UUID) async throws {
        try await store.mutate { $0.history.removeAll { $0.id == id } }
    }

    func clearAll() async throws {
        try await store.mutate { $0.history.removeAll() }
    }
}

// MARK: - Dishes

@MainActor
final class LocalDishRepository: DishRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var dishesPublisher: AnyPublisher<[Dish], Never> {
        store.$snapshot.map(\.dishes).removeDuplicates().eraseToAnyPublisher()
    }

    func dishes(includeArchived: Bool) -> [Dish] {
        store.snapshot.dishes.filter { includeArchived || !$0.isArchived }
    }

    func dish(id: UUID) -> Dish? {
        store.snapshot.dishes.first { $0.id == id }
    }

    func add(_ dish: Dish) async throws {
        try await store.mutate { $0.dishes.append(dish) }
    }

    func update(_ dish: Dish) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.dishes.firstIndex(where: { $0.id == dish.id }) else {
                throw DomainError.notFound("That dish no longer exists.")
            }
            var updated = dish
            updated.updatedAt = Date()
            snapshot.dishes[index] = updated
        }
    }

    func delete(id: UUID) async throws {
        try await store.mutate { snapshot in
            snapshot.dishes.removeAll { $0.id == id }
            let removedEntries = snapshot.mealEntries.filter { $0.dishId == id }.map(\.id)
            snapshot.mealEntries.removeAll { $0.dishId == id }
            // Auto shopping rows generated for those meals lose their reason to
            // exist, so they go with them.
            snapshot.shoppingItems.removeAll { item in
                guard let entryId = item.origin.mealEntryId else { return false }
                return removedEntries.contains(entryId)
            }
            for index in snapshot.prepTasks.indices where snapshot.prepTasks[index].linkedDishId == id {
                snapshot.prepTasks[index].linkedDishId = nil
            }
        }
    }
}

// MARK: - Meal plan

@MainActor
final class LocalMealPlanRepository: MealPlanRepository {
    private let store: PantryStore
    private let calendar = Calendar.current

    init(store: PantryStore) { self.store = store }

    var entriesPublisher: AnyPublisher<[MealPlanEntry], Never> {
        store.$snapshot.map(\.mealEntries).removeDuplicates().eraseToAnyPublisher()
    }

    func entries() -> [MealPlanEntry] { store.snapshot.mealEntries }

    func entries(on day: Date) -> [MealPlanEntry] {
        let start = calendar.startOfDay(for: day)
        return store.snapshot.mealEntries
            .filter { calendar.startOfDay(for: $0.date) == start }
            .sorted { $0.slot.sortIndex < $1.slot.sortIndex }
    }

    func entry(id: UUID) -> MealPlanEntry? {
        store.snapshot.mealEntries.first { $0.id == id }
    }

    func add(_ entry: MealPlanEntry) async throws {
        try await store.mutate { $0.mealEntries.append(entry) }
    }

    func update(_ entry: MealPlanEntry) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.mealEntries.firstIndex(where: { $0.id == entry.id }) else {
                throw DomainError.notFound("That meal is no longer in the plan.")
            }
            // Moving a meal replaces it in place — it never leaves a duplicate.
            snapshot.mealEntries[index] = entry
        }
    }

    func delete(ids: [UUID]) async throws {
        let idSet = Set(ids)
        try await store.mutate { snapshot in
            snapshot.mealEntries.removeAll { idSet.contains($0.id) }
            snapshot.shoppingItems.removeAll { item in
                guard let entryId = item.origin.mealEntryId else { return false }
                return idSet.contains(entryId)
            }
        }
    }
}

// MARK: - Shopping

@MainActor
final class LocalShoppingRepository: ShoppingRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var itemsPublisher: AnyPublisher<[ShoppingItem], Never> {
        store.$snapshot.map(\.shoppingItems).removeDuplicates().eraseToAnyPublisher()
    }

    func items() -> [ShoppingItem] { store.snapshot.shoppingItems }

    func item(id: UUID) -> ShoppingItem? {
        store.snapshot.shoppingItems.first { $0.id == id }
    }

    func add(_ item: ShoppingItem) async throws {
        try await store.mutate { $0.shoppingItems.append(item) }
    }

    func update(_ item: ShoppingItem) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.shoppingItems.firstIndex(where: { $0.id == item.id }) else {
                throw DomainError.notFound("That shopping row no longer exists.")
            }
            snapshot.shoppingItems[index] = item
        }
    }

    func upsert(_ items: [ShoppingItem]) async throws {
        try await store.mutate { snapshot in
            for item in items {
                if let index = snapshot.shoppingItems.firstIndex(where: { $0.id == item.id }) {
                    snapshot.shoppingItems[index] = item
                } else {
                    snapshot.shoppingItems.append(item)
                }
            }
        }
    }

    func delete(ids: [UUID]) async throws {
        let idSet = Set(ids)
        try await store.mutate { snapshot in
            // Automatic rows are protected: they may only leave the list once
            // the user has given a reason (which sets `.excluded`).
            let blocked = snapshot.shoppingItems.filter {
                idSet.contains($0.id) && $0.origin.isAutomatic && $0.status != .excluded
            }
            guard blocked.isEmpty else {
                throw DomainError.conflict(
                    "Automatic items need a reason before they can leave the list."
                )
            }
            snapshot.shoppingItems.removeAll { idSet.contains($0.id) }
        }
    }
}

// MARK: - Prep tasks

@MainActor
final class LocalPrepRepository: PrepRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var tasksPublisher: AnyPublisher<[PrepTask], Never> {
        store.$snapshot.map(\.prepTasks).removeDuplicates().eraseToAnyPublisher()
    }

    func tasks() -> [PrepTask] { store.snapshot.prepTasks }

    func task(id: UUID) -> PrepTask? {
        store.snapshot.prepTasks.first { $0.id == id }
    }

    func add(_ task: PrepTask) async throws {
        try await store.mutate { $0.prepTasks.append(task) }
    }

    func update(_ task: PrepTask) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.prepTasks.firstIndex(where: { $0.id == task.id }) else {
                throw DomainError.notFound("That task no longer exists.")
            }
            snapshot.prepTasks[index] = task
        }
    }

    func delete(id: UUID) async throws {
        try await store.mutate { snapshot in
            snapshot.prepTasks.removeAll { $0.id == id }
            for index in snapshot.prepTasks.indices where snapshot.prepTasks[index].dependencyId == id {
                snapshot.prepTasks[index].dependencyId = nil
            }
        }
    }
}

// MARK: - Leftovers

@MainActor
final class LocalLeftoverRepository: LeftoverRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var leftoversPublisher: AnyPublisher<[Leftover], Never> {
        store.$snapshot.map(\.leftovers).removeDuplicates().eraseToAnyPublisher()
    }

    func leftovers() -> [Leftover] { store.snapshot.leftovers }

    func leftover(id: UUID) -> Leftover? {
        store.snapshot.leftovers.first { $0.id == id }
    }

    func add(_ leftover: Leftover) async throws {
        try await store.mutate { $0.leftovers.append(leftover) }
    }

    func update(_ leftover: Leftover) async throws {
        try await store.mutate { snapshot in
            guard let index = snapshot.leftovers.firstIndex(where: { $0.id == leftover.id }) else {
                throw DomainError.notFound("That leftover no longer exists.")
            }
            snapshot.leftovers[index] = leftover
        }
    }

    func delete(id: UUID) async throws {
        try await store.mutate { $0.leftovers.removeAll { $0.id == id } }
    }
}

// MARK: - Settings

@MainActor
final class LocalSettingsRepository: SettingsRepository {
    private let store: PantryStore

    init(store: PantryStore) { self.store = store }

    var settingsPublisher: AnyPublisher<AppSettings, Never> {
        store.$snapshot.map(\.settings).removeDuplicates().eraseToAnyPublisher()
    }

    func settings() -> AppSettings { store.snapshot.settings }

    func save(_ settings: AppSettings) async throws {
        try await store.mutate { $0.settings = settings }
    }
}
