//
//  CoverageService.swift
//  HarborPantry
//
//  Domain layer — matches dish ingredients against what is actually in stock.
//

import Foundation

struct CoverageService {

    /// Computes coverage for one dish at a given serving count.
    ///
    /// Matching is by name (case-insensitive) or by an explicit inventory link.
    /// Quantities only combine when the units share a dimension; otherwise the
    /// row is flagged as a unit conflict for the user to resolve by hand.
    func coverage(for dish: Dish, servings: Int, inventory: [Product]) -> DishCoverage {
        let scaled = dish.ingredients(scaledTo: servings)
        let active = inventory.filter { !$0.isArchived && $0.quantity > 0 }

        let rows: [IngredientCoverage] = scaled.map { ingredient in
            let matches = active.filter { product in
                if let linked = ingredient.linkedProductId, product.id == linked { return true }
                return product.trimmedName.compare(
                    ingredient.trimmedName,
                    options: .caseInsensitive
                ) == .orderedSame
            }

            var available = 0.0
            var contributing: [UUID] = []
            var conflict = false

            for product in matches {
                if let converted = product.unit.convert(product.quantity, to: ingredient.unit) {
                    available += converted
                    contributing.append(product.id)
                } else {
                    // Same product, incompatible unit — never guess a conversion.
                    conflict = true
                }
            }

            return IngredientCoverage(
                ingredient: ingredient,
                required: ingredient.quantity.roundedToTwoDecimals,
                available: available.roundedToTwoDecimals,
                matchedProductIds: contributing,
                hasUnitConflict: conflict && available <= 0
            )
        }

        return DishCoverage(dishId: dish.id, servings: servings, ingredients: rows)
    }

    /// Aggregates the shortfall across several planned meals so the shopping
    /// list can carry one row per ingredient instead of one per meal.
    func aggregatedShortfall(
        entries: [MealPlanEntry],
        dishes: [Dish],
        inventory: [Product]
    ) -> [ShortfallLine] {
        let dishesById = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        var accumulator: [ShortfallKey: ShortfallLine] = [:]

        for entry in entries {
            guard let dish = dishesById[entry.dishId] else { continue }
            let result = coverage(for: dish, servings: entry.totalServings, inventory: inventory)

            for row in result.ingredients where row.status != .available {
                let key = ShortfallKey(
                    name: row.ingredient.trimmedName.lowercased(),
                    unit: row.ingredient.unit
                )
                if var existing = accumulator[key] {
                    existing.required += row.required
                    existing.alreadyHave += row.available
                    existing.entryIds.append(entry.id)
                    accumulator[key] = existing
                } else {
                    accumulator[key] = ShortfallLine(
                        name: row.ingredient.trimmedName,
                        category: row.ingredient.category,
                        unit: row.ingredient.unit,
                        required: row.required,
                        alreadyHave: row.available,
                        entryIds: [entry.id],
                        dishId: dish.id,
                        ingredientId: row.ingredient.id
                    )
                }
            }
        }

        return accumulator.values
            .map { line in
                var normalized = line
                normalized.required = line.required.roundedToTwoDecimals
                normalized.alreadyHave = line.alreadyHave.roundedToTwoDecimals
                return normalized
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private struct ShortfallKey: Hashable {
        let name: String
        let unit: MeasurementUnit
    }
}

/// One aggregated missing ingredient, ready to become a shopping row.
struct ShortfallLine: Hashable, Identifiable {
    var name: String
    var category: ProductCategory
    var unit: MeasurementUnit
    var required: Double
    var alreadyHave: Double
    var entryIds: [UUID]
    var dishId: UUID
    var ingredientId: UUID

    var id: String { "\(name.lowercased())-\(unit.rawValue)" }

    var missing: Double {
        max(0, required - alreadyHave).roundedToTwoDecimals
    }
}
