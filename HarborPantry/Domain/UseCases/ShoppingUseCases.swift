//
//  ShoppingUseCases.swift
//  HarborPantry
//
//  Domain layer — the shopping list, and the bridge back into inventory.
//

import Foundation

/// The confirmation the user fills in when a purchased row becomes stock.
struct PurchaseConfirmation {
    var quantity: Double
    var unit: MeasurementUnit
    var zoneId: UUID
    var useByDate: Date?
    var actualPrice: Double?
}

struct ShoppingUndoToken: Hashable, Identifiable {
    let id: UUID
    let itemId: UUID
    let previousStatus: ShoppingItemStatus
    let previousPurchasedAt: Date?
    let previousActualPrice: Double?
    /// Product created by the purchase, so undo can take it back out again.
    let createdProductId: UUID?
    let historyEntryId: UUID?
    let label: String
}

@MainActor
struct ShoppingUseCases {
    private let shopping: ShoppingRepository
    private let plan: MealPlanRepository
    private let dishes: DishRepository
    private let products: ProductRepository
    private let history: HistoryRepository
    private let coverageService = CoverageService()

    init(
        shopping: ShoppingRepository,
        plan: MealPlanRepository,
        dishes: DishRepository,
        products: ProductRepository,
        history: HistoryRepository
    ) {
        self.shopping = shopping
        self.plan = plan
        self.dishes = dishes
        self.products = products
        self.history = history
    }

    // MARK: - Generating rows from the plan

    /// Recomputes the automatic rows from the current plan and inventory.
    ///
    /// Rows the user already purchased or excluded are left exactly as they
    /// are — regenerating never silently undoes the user's decisions.
    @discardableResult
    func syncAutomaticItems(for entries: [MealPlanEntry]) async throws -> Int {
        let shortfalls = coverageService.aggregatedShortfall(
            entries: entries,
            dishes: dishes.dishes(includeArchived: true),
            inventory: products.products(includeArchived: false)
        )

        let existing = shopping.items()
        var updates: [ShoppingItem] = []
        var addedCount = 0

        for line in shortfalls {
            let match = existing.first { item in
                item.origin.isAutomatic
                    && item.unit == line.unit
                    && item.trimmedName.compare(line.name, options: .caseInsensitive) == .orderedSame
            }

            if let current = match {
                guard current.status == .pending else { continue }
                var updated = current
                updated.requiredQuantity = line.required
                updated.alreadyHave = line.alreadyHave
                updated.category = line.category
                updates.append(updated)
            } else {
                let alreadyResolved = existing.contains { item in
                    item.origin.isAutomatic
                        && item.status != .pending
                        && item.trimmedName.compare(line.name, options: .caseInsensitive) == .orderedSame
                }
                guard !alreadyResolved else { continue }

                updates.append(
                    ShoppingItem(
                        name: line.name,
                        category: line.category,
                        requiredQuantity: line.required,
                        alreadyHave: line.alreadyHave,
                        unit: line.unit,
                        origin: .mealPlan(
                            entryId: line.entryIds.first ?? UUID(),
                            dishId: line.dishId,
                            ingredientId: line.ingredientId
                        )
                    )
                )
                addedCount += 1
            }
        }

        guard !updates.isEmpty else { return 0 }
        try await shopping.upsert(updates)
        return addedCount
    }

    /// Adds the missing ingredients of a single dish or planned meal.
    @discardableResult
    func addMissing(from coverage: DishCoverage, dishId: UUID, entryId: UUID?) async throws -> Int {
        var newItems: [ShoppingItem] = []
        let existing = shopping.items()

        for row in coverage.ingredients where row.status != .available {
            let duplicate = existing.contains { item in
                item.status == .pending
                    && item.unit == row.ingredient.unit
                    && item.trimmedName.compare(
                        row.ingredient.trimmedName,
                        options: .caseInsensitive
                    ) == .orderedSame
            }
            guard !duplicate else { continue }

            let origin: ShoppingItemOrigin = entryId.map {
                .mealPlan(entryId: $0, dishId: dishId, ingredientId: row.ingredient.id)
            } ?? .manual

            newItems.append(
                ShoppingItem(
                    name: row.ingredient.trimmedName,
                    category: row.ingredient.category,
                    requiredQuantity: row.required,
                    alreadyHave: row.available,
                    unit: row.ingredient.unit,
                    origin: origin
                )
            )
        }

        guard !newItems.isEmpty else { return 0 }
        try await shopping.upsert(newItems)
        return newItems.count
    }

    func addCustomItem(
        name: String,
        category: ProductCategory,
        quantity: Double,
        unit: MeasurementUnit,
        store: String,
        estimatedPrice: Double?,
        shopper: String
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Item name is required.")
        }
        guard quantity > 0 else {
            throw DomainError.validation("Quantity must be greater than zero.")
        }
        try await shopping.add(
            ShoppingItem(
                name: trimmed,
                category: category,
                requiredQuantity: quantity,
                unit: unit,
                store: store,
                estimatedPrice: estimatedPrice,
                shopper: shopper,
                origin: .manual
            )
        )
    }

    // MARK: - Purchasing

    /// Marks a row purchased and puts the goods into inventory.
    ///
    /// Inventory only grows once the user has confirmed the amount and the
    /// storage zone in `confirmation`.
    @discardableResult
    func markPurchased(
        itemId: UUID,
        confirmation: PurchaseConfirmation
    ) async throws -> ShoppingUndoToken {
        guard let item = shopping.item(id: itemId) else {
            throw DomainError.notFound("That shopping row no longer exists.")
        }
        guard confirmation.quantity > 0 else {
            throw DomainError.validation("Confirm how much you actually bought.")
        }

        var updated = item
        updated.status = .purchased
        updated.purchasedAt = Date()
        updated.actualPrice = confirmation.actualPrice
        try await shopping.update(updated)

        // Fold into an existing matching row when the unit already agrees,
        // otherwise create a new product.
        let matching = products.products(includeArchived: false).first { product in
            product.zoneId == confirmation.zoneId
                && product.unit == confirmation.unit
                && product.trimmedName.compare(item.trimmedName, options: .caseInsensitive) == .orderedSame
        }

        var createdProductId: UUID?
        if var existing = matching {
            existing.quantity = (existing.quantity + confirmation.quantity).roundedToTwoDecimals
            if let newDate = confirmation.useByDate {
                existing.useByDate = existing.useByDate.map { min($0, newDate) } ?? newDate
            }
            existing.updatedAt = Date()
            try await products.update(existing)
            createdProductId = nil
        } else {
            let product = Product(
                name: item.trimmedName,
                category: item.category,
                quantity: confirmation.quantity,
                unit: confirmation.unit,
                zoneId: confirmation.zoneId,
                purchaseDate: Date(),
                useByDate: confirmation.useByDate,
                price: confirmation.actualPrice ?? item.estimatedPrice
            )
            try await products.add(product)
            createdProductId = product.id
        }

        let entry = ProductHistoryEntry(
            productId: createdProductId ?? matching?.id,
            productName: item.trimmedName,
            kind: .purchased,
            quantityDelta: confirmation.quantity,
            unit: confirmation.unit,
            category: item.category,
            note: item.storeLabel
        )
        try await history.record(entry)

        return ShoppingUndoToken(
            id: UUID(),
            itemId: item.id,
            previousStatus: item.status,
            previousPurchasedAt: item.purchasedAt,
            previousActualPrice: item.actualPrice,
            createdProductId: createdProductId,
            historyEntryId: entry.id,
            label: "Purchased \(item.trimmedName)"
        )
    }

    func undoPurchase(_ token: ShoppingUndoToken) async throws {
        if var item = shopping.item(id: token.itemId) {
            item.status = token.previousStatus
            item.purchasedAt = token.previousPurchasedAt
            item.actualPrice = token.previousActualPrice
            try await shopping.update(item)
        }
        if let productId = token.createdProductId {
            try await products.delete(ids: [productId])
        }
        if let historyId = token.historyEntryId {
            try await history.remove(id: historyId)
        }
    }

    // MARK: - Excluding and organising

    /// Automatic rows require a reason before they leave the list.
    func excludeAutomaticItem(itemId: UUID, reason: String) async throws {
        guard var item = shopping.item(id: itemId) else {
            throw DomainError.notFound("That shopping row no longer exists.")
        }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Add a short reason so the list stays honest.")
        }
        item.status = .excluded
        item.exclusionReason = trimmed
        try await shopping.update(item)
    }

    func restore(itemId: UUID) async throws {
        guard var item = shopping.item(id: itemId) else {
            throw DomainError.notFound("That shopping row no longer exists.")
        }
        item.status = .pending
        item.exclusionReason = ""
        item.purchasedAt = nil
        try await shopping.update(item)
    }

    func setStore(itemIds: [UUID], store: String) async throws {
        var updates: [ShoppingItem] = []
        for id in itemIds {
            guard var item = shopping.item(id: id) else { continue }
            item.store = store.trimmingCharacters(in: .whitespacesAndNewlines)
            updates.append(item)
        }
        guard !updates.isEmpty else { return }
        try await shopping.upsert(updates)
    }

    func update(_ item: ShoppingItem) async throws {
        try await shopping.update(item)
    }

    /// Manual rows can be deleted outright; automatic ones must be excluded.
    func delete(itemId: UUID) async throws {
        guard let item = shopping.item(id: itemId) else { return }
        guard !item.origin.isAutomatic || item.status == .excluded else {
            throw DomainError.conflict(
                "This item came from your meal plan. Exclude it with a reason instead of deleting it."
            )
        }
        try await shopping.delete(ids: [itemId])
    }
}
