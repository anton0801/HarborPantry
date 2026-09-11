//
//  MealPlanUseCases.swift
//  HarborPantry
//
//  Domain layer — planning meals, scaling portions and checking coverage.
//

import Foundation

/// What a serving change would do, shown before anything is written.
struct ServingsPreview: Hashable {
    struct Line: Hashable, Identifiable {
        let id: UUID
        let name: String
        let currentQuantity: Double
        let newQuantity: Double
        let unit: MeasurementUnit

        var delta: Double { (newQuantity - currentQuantity).roundedToTwoDecimals }
    }

    let currentServings: Int
    let newServings: Int
    let lines: [Line]
    let newlyMissingCount: Int
}

@MainActor
struct MealPlanUseCases {
    private let plan: MealPlanRepository
    private let dishes: DishRepository
    private let products: ProductRepository
    private let coverageService = CoverageService()
    private let calendar = Calendar.current

    init(plan: MealPlanRepository, dishes: DishRepository, products: ProductRepository) {
        self.plan = plan
        self.dishes = dishes
        self.products = products
    }

    // MARK: - Reads

    func coverage(for entry: MealPlanEntry) -> DishCoverage? {
        guard let dish = dishes.dish(id: entry.dishId) else { return nil }
        return coverageService.coverage(
            for: dish,
            servings: entry.totalServings,
            inventory: products.products(includeArchived: false)
        )
    }

    func coverage(for dish: Dish, servings: Int) -> DishCoverage {
        coverageService.coverage(
            for: dish,
            servings: servings,
            inventory: products.products(includeArchived: false)
        )
    }

    func entries(on day: Date) -> [MealPlanEntry] {
        plan.entries(on: day)
    }

    /// The seven days of the plan week containing `date`, honouring the
    /// household's chosen first day of the week.
    func weekDays(containing date: Date, weekStart: Weekday) -> [Date] {
        var calendar = self.calendar
        calendar.firstWeekday = weekStart.rawValue
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday - weekStart.rawValue + 7) % 7
        guard let first = calendar.date(byAdding: .day, value: -offset, to: start) else {
            return [start]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    // MARK: - Writes

    func addDish(
        dishId: UUID,
        date: Date,
        slot: MealSlot,
        customSlotName: String = "",
        servings: Int,
        guests: Int
    ) async throws -> MealPlanEntry {
        guard dishes.dish(id: dishId) != nil else {
            throw DomainError.notFound("That dish no longer exists.")
        }
        guard servings + guests > 0 else {
            throw DomainError.validation("A meal needs at least one serving.")
        }
        let entry = MealPlanEntry(
            dishId: dishId,
            date: date,
            slot: slot,
            customSlotName: customSlotName,
            servings: servings,
            guests: guests
        )
        try await plan.add(entry)
        return entry
    }

    /// Moves an existing meal. The entry keeps its id, so no duplicate appears.
    func move(entryId: UUID, to date: Date, slot: MealSlot) async throws {
        guard var entry = plan.entry(id: entryId) else {
            throw DomainError.notFound("That meal is no longer in the plan.")
        }
        entry.date = calendar.startOfDay(for: date)
        entry.slot = slot
        try await plan.update(entry)
    }

    /// Builds the recalculation preview the user confirms before a change.
    func servingsPreview(for entryId: UUID, newTotalServings: Int) throws -> ServingsPreview {
        guard let entry = plan.entry(id: entryId) else {
            throw DomainError.notFound("That meal is no longer in the plan.")
        }
        guard let dish = dishes.dish(id: entry.dishId) else {
            throw DomainError.notFound("That dish no longer exists.")
        }
        guard newTotalServings > 0 else {
            throw DomainError.validation("Serving count must be greater than zero.")
        }

        let current = dish.ingredients(scaledTo: entry.totalServings)
        let updated = dish.ingredients(scaledTo: newTotalServings)
        let lines = zip(current, updated).map { old, new in
            ServingsPreview.Line(
                id: old.id,
                name: old.trimmedName,
                currentQuantity: old.quantity,
                newQuantity: new.quantity,
                unit: old.unit
            )
        }

        let before = coverageService.coverage(
            for: dish,
            servings: entry.totalServings,
            inventory: products.products(includeArchived: false)
        )
        let after = coverageService.coverage(
            for: dish,
            servings: newTotalServings,
            inventory: products.products(includeArchived: false)
        )

        return ServingsPreview(
            currentServings: entry.totalServings,
            newServings: newTotalServings,
            lines: lines,
            newlyMissingCount: max(0, after.missingCount - before.missingCount)
        )
    }

    func applyServings(entryId: UUID, servings: Int, guests: Int) async throws {
        guard var entry = plan.entry(id: entryId) else {
            throw DomainError.notFound("That meal is no longer in the plan.")
        }
        guard servings + guests > 0 else {
            throw DomainError.validation("A meal needs at least one serving.")
        }
        entry.servings = max(1, servings)
        entry.guests = max(0, guests)
        try await plan.update(entry)
    }

    /// Copies every meal from one day onto another. Copies are new entries;
    /// the source day is untouched.
    func duplicateDay(from source: Date, to destination: Date) async throws -> Int {
        let sourceEntries = plan.entries(on: source)
        guard !sourceEntries.isEmpty else {
            throw DomainError.validation("There are no meals on that day to copy.")
        }
        for entry in sourceEntries {
            let copy = MealPlanEntry(
                dishId: entry.dishId,
                date: destination,
                slot: entry.slot,
                customSlotName: entry.customSlotName,
                servings: entry.servings,
                guests: entry.guests,
                note: entry.note
            )
            try await plan.add(copy)
        }
        return sourceEntries.count
    }

    func clearDay(_ day: Date) async throws -> Int {
        let ids = plan.entries(on: day).map(\.id)
        guard !ids.isEmpty else { return 0 }
        try await plan.delete(ids: ids)
        return ids.count
    }

    func remove(entryId: UUID) async throws {
        try await plan.delete(ids: [entryId])
    }
}
