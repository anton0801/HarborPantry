//
//  DishBuilderViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class DishBuilderViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var category: DishCategory = .dinner
    @Published var servings: Int = 2
    @Published var ingredients: [DishIngredient] = []
    @Published var steps: [String] = []
    @Published var prepMinutes: Int = 15
    @Published var cookMinutes: Int = 20
    @Published var dietaryTags: [String] = []
    @Published var allergenNotes: String = ""

    @Published private(set) var coverage: DishCoverage?
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published private(set) var isSaving = false

    private let dishUseCases: DishUseCases
    private let shoppingUseCases: ShoppingUseCases
    private let productRepository: ProductRepository
    private let existing: Dish?

    convenience init(dependencies: AppDependencies, dish: Dish?) {
        self.init(
            dish: dish,
            dishUseCases: dependencies.dishUseCases,
            shoppingUseCases: dependencies.shoppingUseCases,
            productRepository: dependencies.productRepository
        )
    }

    init(
        dish: Dish?,
        dishUseCases: DishUseCases,
        shoppingUseCases: ShoppingUseCases,
        productRepository: ProductRepository
    ) {
        self.existing = dish
        self.dishUseCases = dishUseCases
        self.shoppingUseCases = shoppingUseCases
        self.productRepository = productRepository

        if let dish = dish {
            name = dish.name
            category = dish.category
            servings = dish.servings
            ingredients = dish.ingredients
            steps = dish.steps
            prepMinutes = dish.prepMinutes
            cookMinutes = dish.cookMinutes
            dietaryTags = dish.dietaryTags
            allergenNotes = dish.allergenNotes
        }
        refreshCoverage()
    }

    var isEditing: Bool { existing != nil }
    var title: String { isEditing ? "Edit Dish" : "New Dish" }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && servings > 0 && !isSaving
    }

    var inventoryProducts: [Product] {
        productRepository.products(includeArchived: false)
            .filter { $0.quantity > 0 }
            .sorted { $0.trimmedName < $1.trimmedName }
    }

    /// Ingredients scaled to the current serving count, for the preview list.
    var scaledIngredients: [DishIngredient] {
        guard let base = existing else { return ingredients }
        return base.ingredients(scaledTo: servings)
    }

    // MARK: - Ingredients

    func addIngredient(name: String, quantity: Double, unit: MeasurementUnit, category: ProductCategory) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Every ingredient needs a name."
            return
        }
        guard quantity > 0 else {
            errorMessage = "Ingredient quantities must be greater than zero."
            return
        }
        ingredients.append(
            DishIngredient(name: trimmed, quantity: quantity, unit: unit, category: category)
        )
        errorMessage = nil
        refreshCoverage()
    }

    func addIngredientFromInventory(productId: UUID, quantity: Double) {
        do {
            let ingredient = try dishUseCases.ingredient(fromProduct: productId, quantity: quantity)
            ingredients.append(ingredient)
            errorMessage = nil
            refreshCoverage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeIngredient(_ id: UUID) {
        ingredients.removeAll { $0.id == id }
        refreshCoverage()
    }

    // MARK: - Steps

    func addStep(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        steps.append(trimmed)
    }

    func removeStep(at index: Int) {
        guard steps.indices.contains(index) else { return }
        steps.remove(at: index)
    }

    // MARK: - Coverage

    func refreshCoverage() {
        let draft = Dish(
            id: existing?.id ?? UUID(),
            name: name.isEmpty ? "Draft" : name,
            category: category,
            servings: max(1, servings),
            ingredients: ingredients
        )
        coverage = dishUseCases.coverage(for: draft, servings: max(1, servings))
    }

    // MARK: - Persistence

    func save() async -> Dish? {
        isSaving = true
        defer { isSaving = false }
        do {
            let dish = try await dishUseCases.save(
                existing: existing,
                name: name,
                category: category,
                servings: servings,
                ingredients: ingredients,
                steps: steps,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                dietaryTags: dietaryTags,
                allergenNotes: allergenNotes
            )
            errorMessage = nil
            return dish
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete() async -> Bool {
        guard let dish = existing else { return false }
        do {
            try await dishUseCases.delete(dishId: dish.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addMissingToShopping() async {
        guard let coverage = coverage else { return }
        do {
            let count = try await shoppingUseCases.addMissing(
                from: coverage,
                dishId: existing?.id ?? coverage.dishId,
                entryId: nil
            )
            toast = ToastState(
                message: count == 0
                    ? "Everything is already on the list."
                    : "Added \(count) item\(count == 1 ? "" : "s") to shopping."
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
