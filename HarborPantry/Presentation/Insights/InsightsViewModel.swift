//
//  InsightsViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var period: InsightsPeriod = .lastThreeWeeks {
        didSet { reload() }
    }
    @Published private(set) var availability: InsightsAvailability = .locked(weeksCompleted: 0, weeksRequired: 3)
    @Published private(set) var summary: InsightsSummary = .empty
    @Published private(set) var history: [ProductHistoryEntry] = []
    @Published var sourceMetric: InsightMetric?

    private let insightsService: InsightsService
    private let historyRepository: HistoryRepository
    private let mealPlanRepository: MealPlanRepository
    private let dishRepository: DishRepository
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            insightsService: dependencies.insightsService,
            historyRepository: dependencies.historyRepository,
            mealPlanRepository: dependencies.mealPlanRepository,
            dishRepository: dependencies.dishRepository,
            store: dependencies.store
        )
    }

    init(
        insightsService: InsightsService,
        historyRepository: HistoryRepository,
        mealPlanRepository: MealPlanRepository,
        dishRepository: DishRepository,
        store: PantryStore
    ) {
        self.insightsService = insightsService
        self.historyRepository = historyRepository
        self.mealPlanRepository = mealPlanRepository
        self.dishRepository = dishRepository
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        history = historyRepository.entries(limit: nil)
        availability = insightsService.availability(from: history)
        summary = insightsService.summary(
            history: history,
            mealEntries: mealPlanRepository.entries(),
            dishes: dishRepository.dishes(includeArchived: true),
            period: period
        )
    }

    var weeksCompleted: Int {
        if case let .locked(completed, _) = availability { return completed }
        return InsightsService.requiredWeeks
    }

    /// The records behind one metric, so every number can be traced back.
    func sourceEntries(for metric: InsightMetric) -> [ProductHistoryEntry] {
        let ids = Set(metric.sourceEntryIds)
        return history.filter { ids.contains($0.id) }
    }
}

@MainActor
final class ArchiveViewModel: ObservableObject {
    @Published private(set) var archivedProducts: [Product] = []
    @Published private(set) var archivedDishes: [Dish] = []
    @Published private(set) var pastMeals: [MealPlanEntry] = []
    @Published private(set) var dishesById: [UUID: Dish] = [:]
    @Published var errorMessage: String?
    @Published var toast: ToastState?

    private let productRepository: ProductRepository
    private let dishRepository: DishRepository
    private let mealPlanRepository: MealPlanRepository
    private let inventoryUseCases: InventoryUseCases
    private let dishUseCases: DishUseCases
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            productRepository: dependencies.productRepository,
            dishRepository: dependencies.dishRepository,
            mealPlanRepository: dependencies.mealPlanRepository,
            inventoryUseCases: dependencies.inventoryUseCases,
            dishUseCases: dependencies.dishUseCases,
            store: dependencies.store
        )
    }

    init(
        productRepository: ProductRepository,
        dishRepository: DishRepository,
        mealPlanRepository: MealPlanRepository,
        inventoryUseCases: InventoryUseCases,
        dishUseCases: DishUseCases,
        store: PantryStore
    ) {
        self.productRepository = productRepository
        self.dishRepository = dishRepository
        self.mealPlanRepository = mealPlanRepository
        self.inventoryUseCases = inventoryUseCases
        self.dishUseCases = dishUseCases
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        archivedProducts = productRepository.products(includeArchived: true).filter(\.isArchived)
        archivedDishes = dishRepository.dishes(includeArchived: true).filter(\.isArchived)
        let today = Calendar.current.startOfDay(for: Date())
        pastMeals = mealPlanRepository.entries()
            .filter { $0.date < today }
            .sorted { $0.date > $1.date }
        dishesById = Dictionary(
            uniqueKeysWithValues: dishRepository.dishes(includeArchived: true).map { ($0.id, $0) }
        )
    }

    var isEmpty: Bool {
        archivedProducts.isEmpty && archivedDishes.isEmpty && pastMeals.isEmpty
    }

    func dishName(_ id: UUID) -> String {
        dishesById[id]?.trimmedName ?? "Removed dish"
    }

    func restore(product: Product) async {
        do {
            try await inventoryUseCases.setArchived(false, productIds: [product.id])
            toast = ToastState(message: "\(product.trimmedName) is back in your inventory.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(dish: Dish) async {
        do {
            try await dishUseCases.setArchived(false, dishId: dish.id)
            toast = ToastState(message: "\(dish.trimmedName) restored.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
