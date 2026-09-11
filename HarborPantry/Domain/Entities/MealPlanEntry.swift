//
//  MealPlanEntry.swift
//  HarborPantry
//
//  Domain layer — one dish placed on one day of the plan.
//

import Foundation

enum MealSlot: String, Codable, CaseIterable, Hashable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .custom: return "star"
        }
    }

    var sortIndex: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .custom: return 3
        }
    }
}

struct MealPlanEntry: Codable, Hashable, Identifiable {
    let id: UUID
    var dishId: UUID
    /// Normalised to the start of the day it belongs to.
    var date: Date
    var slot: MealSlot
    /// Free-text name shown when `slot == .custom`.
    var customSlotName: String
    /// People eating from the household.
    var servings: Int
    /// Extra guests on top of `servings`.
    var guests: Int
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dishId: UUID,
        date: Date,
        slot: MealSlot,
        customSlotName: String = "",
        servings: Int,
        guests: Int = 0,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dishId = dishId
        self.date = Calendar.current.startOfDay(for: date)
        self.slot = slot
        self.customSlotName = customSlotName
        self.servings = max(1, servings)
        self.guests = max(0, guests)
        self.note = note
        self.createdAt = createdAt
    }

    /// Total plates this entry has to cover.
    var totalServings: Int { max(1, servings + guests) }

    var slotTitle: String {
        if slot == .custom {
            let trimmed = customSlotName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Custom" : trimmed
        }
        return slot.displayName
    }
}

// MARK: - Coverage

/// How much of a dish the pantry can already cover.
enum CoverageStatus: String, Codable, Hashable, CaseIterable {
    case available
    case partial
    case missing

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .partial: return "Partial"
        case .missing: return "Missing"
        }
    }

    var symbolName: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .missing: return "exclamationmark.circle.fill"
        }
    }
}

/// Coverage of a single ingredient against current inventory.
struct IngredientCoverage: Hashable, Identifiable {
    let ingredient: DishIngredient
    /// Required amount after scaling to the planned servings.
    let required: Double
    /// How much inventory can supply, expressed in the ingredient's unit.
    let available: Double
    /// Inventory rows that contributed to `available`.
    let matchedProductIds: [UUID]
    /// True when a same-named product exists but in an incompatible unit, so
    /// the app refuses to convert and asks the user to decide.
    let hasUnitConflict: Bool

    var id: UUID { ingredient.id }

    var missing: Double {
        max(0, (required - available)).roundedToTwoDecimals
    }

    var status: CoverageStatus {
        if hasUnitConflict { return .partial }
        if available <= 0 { return .missing }
        if available + 0.0001 >= required { return .available }
        return .partial
    }
}

/// Coverage of a whole dish.
struct DishCoverage: Hashable {
    let dishId: UUID
    let servings: Int
    let ingredients: [IngredientCoverage]

    var status: CoverageStatus {
        guard !ingredients.isEmpty else { return .missing }
        if ingredients.allSatisfy({ $0.status == .available }) { return .available }
        if ingredients.allSatisfy({ $0.status == .missing }) { return .missing }
        return .partial
    }

    var missingCount: Int {
        ingredients.filter { $0.status != .available }.count
    }
}
