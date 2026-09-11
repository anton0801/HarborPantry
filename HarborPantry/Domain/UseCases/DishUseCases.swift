//
//  DishUseCases.swift
//  HarborPantry
//
//  Domain layer — building dishes and scaling them for guests.
//

import Foundation

@MainActor
struct DishUseCases {
    private let dishes: DishRepository
    private let products: ProductRepository
    private let validator = DishValidator()
    private let coverageService = CoverageService()

    init(dishes: DishRepository, products: ProductRepository) {
        self.dishes = dishes
        self.products = products
    }

    func save(
        existing: Dish?,
        name: String,
        category: DishCategory,
        servings: Int,
        ingredients: [DishIngredient],
        steps: [String],
        prepMinutes: Int,
        cookMinutes: Int,
        dietaryTags: [String],
        allergenNotes: String
    ) async throws -> Dish {
        try validator.validate(name: name, servings: servings, ingredients: ingredients)

        let cleanedSteps = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanedTags = dietaryTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var dish = Dish(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            servings: servings,
            ingredients: ingredients,
            steps: cleanedSteps,
            prepMinutes: max(0, prepMinutes),
            cookMinutes: max(0, cookMinutes),
            dietaryTags: cleanedTags,
            allergenNotes: allergenNotes,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        dish.isArchived = existing?.isArchived ?? false

        if existing == nil {
            try await dishes.add(dish)
        } else {
            try await dishes.update(dish)
        }
        return dish
    }

    /// Turns an inventory row into an ingredient, carrying over its unit so no
    /// conversion has to be guessed later.
    func ingredient(fromProduct id: UUID, quantity: Double) throws -> DishIngredient {
        guard let product = products.product(id: id) else {
            throw DomainError.notFound("That product no longer exists.")
        }
        guard quantity > 0 else {
            throw DomainError.validation("Quantity must be greater than zero.")
        }
        return DishIngredient(
            name: product.trimmedName,
            quantity: quantity,
            unit: product.unit,
            category: product.category,
            linkedProductId: product.id
        )
    }

    func coverage(for dish: Dish, servings: Int) -> DishCoverage {
        coverageService.coverage(
            for: dish,
            servings: servings,
            inventory: products.products(includeArchived: false)
        )
    }

    /// Scales a dish's own ingredient list for a different number of plates.
    func scaledIngredients(_ dish: Dish, to servings: Int) -> [DishIngredient] {
        dish.ingredients(scaledTo: max(1, servings))
    }

    func delete(dishId: UUID) async throws {
        try await dishes.delete(id: dishId)
    }

    func setArchived(_ archived: Bool, dishId: UUID) async throws {
        guard var dish = dishes.dish(id: dishId) else {
            throw DomainError.notFound("That dish no longer exists.")
        }
        dish.isArchived = archived
        try await dishes.update(dish)
    }
}
