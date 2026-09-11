//
//  Dish.swift
//  HarborPantry
//
//  Domain layer — a dish and the ingredients it needs.
//

import Foundation

enum DishCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    case dessert
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .dessert: return "Dessert"
        case .other: return "Other"
        }
    }
}

struct DishIngredient: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    /// Quantity required for the dish's own `servings` value.
    var quantity: Double
    var unit: MeasurementUnit
    var category: ProductCategory
    /// Set when the user picked the ingredient straight out of Inventory.
    var linkedProductId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        category: ProductCategory = .other,
        linkedProductId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.linkedProductId = linkedProductId
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct Dish: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var category: DishCategory
    /// Always greater than zero — enforced by `DishValidator`.
    var servings: Int
    var ingredients: [DishIngredient]
    var steps: [String]
    var prepMinutes: Int
    var cookMinutes: Int
    var dietaryTags: [String]
    /// Notes typed by the user. Harbor Pantry repeats them verbatim and makes
    /// no allergen guarantee of its own.
    var allergenNotes: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: DishCategory = .dinner,
        servings: Int = 2,
        ingredients: [DishIngredient] = [],
        steps: [String] = [],
        prepMinutes: Int = 0,
        cookMinutes: Int = 0,
        dietaryTags: [String] = [],
        allergenNotes: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.servings = max(1, servings)
        self.ingredients = ingredients
        self.steps = steps
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.dietaryTags = dietaryTags
        self.allergenNotes = allergenNotes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Scales every ingredient from the dish's base `servings` to `target`.
    func ingredients(scaledTo target: Int) -> [DishIngredient] {
        guard servings > 0, target > 0, target != servings else { return ingredients }
        let factor = Double(target) / Double(servings)
        return ingredients.map { ingredient in
            var scaled = ingredient
            scaled.quantity = (ingredient.quantity * factor).roundedToTwoDecimals
            return scaled
        }
    }
}

extension Double {
    var roundedToTwoDecimals: Double {
        (self * 100).rounded() / 100
    }

    /// Formats a quantity without trailing zeroes ("2" not "2.00", "1.5" stays).
    var quantityText: String {
        let rounded = roundedToTwoDecimals
        if rounded == rounded.rounded() && abs(rounded) < 1e9 {
            return String(Int(rounded))
        }
        return String(format: "%.2f", rounded)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
