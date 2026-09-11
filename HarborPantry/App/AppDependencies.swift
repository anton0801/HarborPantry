//
//  AppDependencies.swift
//  HarborPantry
//
//  Composition root — the only place that knows every layer at once.
//

import Foundation
import Combine

@MainActor
final class AppDependencies: ObservableObject {
    // Data
    let store: PantryStore
    let photoStore: PhotoStoring
    let reminderScheduler: ReminderScheduling

    // Repositories
    let profileRepository: ProfileRepository
    let zoneRepository: StorageZoneRepository
    let productRepository: ProductRepository
    let historyRepository: HistoryRepository
    let dishRepository: DishRepository
    let mealPlanRepository: MealPlanRepository
    let shoppingRepository: ShoppingRepository
    let prepRepository: PrepRepository
    let leftoverRepository: LeftoverRepository
    let settingsRepository: SettingsRepository
    let maintenanceRepository: DataMaintenanceRepository

    // Use cases
    let inventoryUseCases: InventoryUseCases
    let mealPlanUseCases: MealPlanUseCases
    let shoppingUseCases: ShoppingUseCases
    let prepUseCases: PrepUseCases
    let profileUseCases: ProfileUseCases
    let dishUseCases: DishUseCases
    let homeUseCases: HomeUseCases

    // Domain services shared with the presentation layer
    let freshnessService = FreshnessService()
    let insightsService = InsightsService()

    /// Defaults are built inside the initializer: both types are main-actor
    /// bound, so they cannot be evaluated as default argument expressions.
    init(store: PantryStore? = nil, photoStore: PhotoStoring? = nil) {
        let store = store ?? PantryStore()
        let photoStore = photoStore ?? PhotoStore()
        self.store = store
        self.photoStore = photoStore
        self.reminderScheduler = ReminderScheduler()

        let profiles = LocalProfileRepository(store: store)
        let zones = LocalStorageZoneRepository(store: store)
        let products = LocalProductRepository(store: store)
        let history = LocalHistoryRepository(store: store)
        let dishes = LocalDishRepository(store: store)
        let plan = LocalMealPlanRepository(store: store)
        let shopping = LocalShoppingRepository(store: store)
        let prep = LocalPrepRepository(store: store)
        let leftovers = LocalLeftoverRepository(store: store)
        let settings = LocalSettingsRepository(store: store)
        let maintenance = LocalDataMaintenanceRepository(store: store, photoStore: photoStore)

        profileRepository = profiles
        zoneRepository = zones
        productRepository = products
        historyRepository = history
        dishRepository = dishes
        mealPlanRepository = plan
        shoppingRepository = shopping
        prepRepository = prep
        leftoverRepository = leftovers
        settingsRepository = settings
        maintenanceRepository = maintenance

        inventoryUseCases = InventoryUseCases(
            products: products,
            history: history,
            zones: zones,
            photos: photoStore
        )
        mealPlanUseCases = MealPlanUseCases(plan: plan, dishes: dishes, products: products)
        shoppingUseCases = ShoppingUseCases(
            shopping: shopping,
            plan: plan,
            dishes: dishes,
            products: products,
            history: history
        )
        prepUseCases = PrepUseCases(
            prep: prep,
            leftovers: leftovers,
            dishes: dishes,
            products: products,
            zones: zones,
            history: history
        )
        profileUseCases = ProfileUseCases(
            profiles: profiles,
            zones: zones,
            settings: settings,
            maintenance: maintenance,
            reminders: reminderScheduler
        )
        dishUseCases = DishUseCases(dishes: dishes, products: products)
        homeUseCases = HomeUseCases(
            products: products,
            zones: zones,
            plan: plan,
            dishes: dishes,
            shopping: shopping,
            prep: prep
        )
    }

    func bootstrap() async {
        await store.load()
    }
}
