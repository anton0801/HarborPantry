//
//  MealPlanViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class MealPlanViewModel: ObservableObject {
    struct PlannedMeal: Identifiable, Hashable {
        let entry: MealPlanEntry
        let dish: Dish
        let coverage: DishCoverage

        var id: UUID { entry.id }
    }

    @Published var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var weekDays: [Date] = []
    @Published private(set) var meals: [PlannedMeal] = []
    @Published private(set) var dishes: [Dish] = []
    @Published private(set) var profile = PantryProfile()
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published var servingsPreview: ServingsPreview?
    @Published var previewEntryId: UUID?

    private let mealPlanUseCases: MealPlanUseCases
    private let shoppingUseCases: ShoppingUseCases
    private let dishRepository: DishRepository
    private let profileRepository: ProfileRepository
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            mealPlanUseCases: dependencies.mealPlanUseCases,
            shoppingUseCases: dependencies.shoppingUseCases,
            dishRepository: dependencies.dishRepository,
            profileRepository: dependencies.profileRepository,
            store: dependencies.store
        )
    }

    init(
        mealPlanUseCases: MealPlanUseCases,
        shoppingUseCases: ShoppingUseCases,
        dishRepository: DishRepository,
        profileRepository: ProfileRepository,
        store: PantryStore
    ) {
        self.mealPlanUseCases = mealPlanUseCases
        self.shoppingUseCases = shoppingUseCases
        self.dishRepository = dishRepository
        self.profileRepository = profileRepository
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        profile = profileRepository.currentProfile()
        weekDays = mealPlanUseCases.weekDays(containing: selectedDay, weekStart: profile.weekStart)
        dishes = dishRepository.dishes(includeArchived: false)
        meals = mealPlanUseCases.entries(on: selectedDay).compactMap { entry in
            guard let dish = dishRepository.dish(id: entry.dishId),
                  let coverage = mealPlanUseCases.coverage(for: entry) else { return nil }
            return PlannedMeal(entry: entry, dish: dish, coverage: coverage)
        }
    }

    func selectDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
        reload()
    }

    func shiftWeek(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: value * 7, to: selectedDay) else { return }
        selectDay(next)
    }

    var hasDishes: Bool { !dishes.isEmpty }
    var isDayEmpty: Bool { meals.isEmpty }

    func mealCount(on day: Date) -> Int {
        mealPlanUseCases.entries(on: day).count
    }

    // MARK: - Actions

    func addDish(
        dishId: UUID,
        slot: MealSlot,
        customName: String,
        servings: Int,
        guests: Int
    ) async {
        do {
            _ = try await mealPlanUseCases.addDish(
                dishId: dishId,
                date: selectedDay,
                slot: slot,
                customSlotName: customName,
                servings: servings,
                guests: guests
            )
            toast = ToastState(message: "Added to the plan.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(entryId: UUID, to day: Date, slot: MealSlot) async {
        do {
            try await mealPlanUseCases.move(entryId: entryId, to: day, slot: slot)
            toast = ToastState(message: "Meal moved.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Builds the preview the user confirms before servings change.
    func prepareServingsChange(entryId: UUID, newTotal: Int) {
        do {
            servingsPreview = try mealPlanUseCases.servingsPreview(
                for: entryId,
                newTotalServings: newTotal
            )
            previewEntryId = entryId
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyServings(entryId: UUID, servings: Int, guests: Int) async {
        do {
            try await mealPlanUseCases.applyServings(
                entryId: entryId,
                servings: servings,
                guests: guests
            )
            servingsPreview = nil
            previewEntryId = nil
            toast = ToastState(message: "Portions recalculated.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func duplicateDay(to destination: Date) async {
        do {
            let count = try await mealPlanUseCases.duplicateDay(from: selectedDay, to: destination)
            toast = ToastState(message: "Copied \(count) meal\(count == 1 ? "" : "s").")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearDay() async {
        do {
            let count = try await mealPlanUseCases.clearDay(selectedDay)
            toast = ToastState(message: count == 0 ? "Nothing to clear." : "Cleared \(count) meal\(count == 1 ? "" : "s").")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(entryId: UUID) async {
        do {
            try await mealPlanUseCases.remove(entryId: entryId)
            toast = ToastState(message: "Removed from the plan.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addMissingToShopping(_ meal: PlannedMeal) async {
        do {
            let count = try await shoppingUseCases.addMissing(
                from: meal.coverage,
                dishId: meal.dish.id,
                entryId: meal.entry.id
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
