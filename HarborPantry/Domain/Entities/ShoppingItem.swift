//
//  ShoppingItem.swift
//  HarborPantry
//
//  Domain layer — one row of the single shared shopping list.
//

import Foundation

enum ShoppingItemStatus: String, Codable, Hashable, CaseIterable {
    case pending
    case purchased
    case excluded

    var displayName: String {
        switch self {
        case .pending: return "To Buy"
        case .purchased: return "Purchased"
        case .excluded: return "Excluded"
        }
    }
}

/// Where the row came from. Auto rows are generated from the meal plan and can
/// only leave the list with an explicit reason from the user.
enum ShoppingItemOrigin: Codable, Hashable {
    case manual
    case mealPlan(entryId: UUID, dishId: UUID, ingredientId: UUID)

    var isAutomatic: Bool {
        if case .mealPlan = self { return true }
        return false
    }

    var mealEntryId: UUID? {
        if case let .mealPlan(entryId, _, _) = self { return entryId }
        return nil
    }

    var ingredientId: UUID? {
        if case let .mealPlan(_, _, ingredientId) = self { return ingredientId }
        return nil
    }
}

struct ShoppingItem: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var category: ProductCategory
    /// Total the plan asks for.
    var requiredQuantity: Double
    /// What inventory already covers at the time the row was generated.
    var alreadyHave: Double
    var unit: MeasurementUnit
    var store: String
    var estimatedPrice: Double?
    var actualPrice: Double?
    var shopper: String
    var status: ShoppingItemStatus
    var origin: ShoppingItemOrigin
    /// Required before an automatic row may be taken off the list.
    var exclusionReason: String
    var note: String
    var createdAt: Date
    var purchasedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        category: ProductCategory = .other,
        requiredQuantity: Double,
        alreadyHave: Double = 0,
        unit: MeasurementUnit,
        store: String = "",
        estimatedPrice: Double? = nil,
        actualPrice: Double? = nil,
        shopper: String = "",
        status: ShoppingItemStatus = .pending,
        origin: ShoppingItemOrigin = .manual,
        exclusionReason: String = "",
        note: String = "",
        createdAt: Date = Date(),
        purchasedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.requiredQuantity = requiredQuantity
        self.alreadyHave = alreadyHave
        self.unit = unit
        self.store = store
        self.estimatedPrice = estimatedPrice
        self.actualPrice = actualPrice
        self.shopper = shopper
        self.status = status
        self.origin = origin
        self.exclusionReason = exclusionReason
        self.note = note
        self.createdAt = createdAt
        self.purchasedAt = purchasedAt
    }

    /// What still has to be bought.
    var toBuy: Double {
        max(0, requiredQuantity - alreadyHave).roundedToTwoDecimals
    }

    var storeLabel: String {
        let trimmed = store.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Any Store" : trimmed
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
