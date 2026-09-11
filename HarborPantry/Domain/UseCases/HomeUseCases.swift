//
//  HomeUseCases.swift
//  HarborPantry
//
//  Domain layer — assembles the dashboard purely from data the user entered.
//

import Foundation

/// The dashboard read model. Every field is derived from real records; when
/// there is nothing to show, the field stays empty rather than being invented.
struct HomeDashboard: Hashable {
    struct MealSummary: Hashable, Identifiable {
        let id: UUID
        let dishName: String
        let slotTitle: String
        let date: Date
        let servings: Int
        let coverage: CoverageStatus
        let missingCount: Int
    }

    struct ZoneSummary: Hashable, Identifiable {
        let id: UUID
        let name: String
        let type: StorageZoneType
        let productCount: Int
        let useSoonCount: Int
        let capacity: Int?
    }

    let useSoon: [Product]
    let reviewCount: Int
    let missingDateCount: Int
    let meals: [MealSummary]
    let shoppingTotal: Int
    let shoppingPurchased: Int
    let zones: [ZoneSummary]
    let nextPrepTask: PrepTask?
    let totalProducts: Int

    var shoppingProgress: Double {
        guard shoppingTotal > 0 else { return 0 }
        return Double(shoppingPurchased) / Double(shoppingTotal)
    }

    var isEmpty: Bool {
        totalProducts == 0 && meals.isEmpty && shoppingTotal == 0
    }

    static let empty = HomeDashboard(
        useSoon: [],
        reviewCount: 0,
        missingDateCount: 0,
        meals: [],
        shoppingTotal: 0,
        shoppingPurchased: 0,
        zones: [],
        nextPrepTask: nil,
        totalProducts: 0
    )
}

@MainActor
struct HomeUseCases {
    private let products: ProductRepository
    private let zones: StorageZoneRepository
    private let plan: MealPlanRepository
    private let dishes: DishRepository
    private let shopping: ShoppingRepository
    private let prep: PrepRepository
    private let freshness = FreshnessService()
    private let coverageService = CoverageService()
    private let calendar = Calendar.current

    init(
        products: ProductRepository,
        zones: StorageZoneRepository,
        plan: MealPlanRepository,
        dishes: DishRepository,
        shopping: ShoppingRepository,
        prep: PrepRepository
    ) {
        self.products = products
        self.zones = zones
        self.plan = plan
        self.dishes = dishes
        self.shopping = shopping
        self.prep = prep
    }

    func dashboard(filter: HomeFilter, now: Date = Date()) -> HomeDashboard {
        let inventory = products.products(includeArchived: false)
        let allDishes = dishes.dishes(includeArchived: true)
        let dishesById = Dictionary(uniqueKeysWithValues: allDishes.map { ($0.id, $0) })

        let windowEnd: Date
        switch filter {
        case .today:
            windowEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                ?? now
        case .thisWeek:
            windowEnd = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))
                ?? now
        }
        let windowStart = calendar.startOfDay(for: now)

        let useSoon = freshness.useSoon(from: inventory, now: now, limit: 6)
        let reviewCount = inventory.filter { freshness.bucket(for: $0, now: now) == .review }.count
        let missingDateCount = inventory.filter { !$0.hasUseByDate }.count

        let plannedEntries = plan.entries()
            .filter { $0.date >= windowStart && $0.date < windowEnd }
            .sorted { lhs, rhs in
                lhs.date == rhs.date
                    ? lhs.slot.sortIndex < rhs.slot.sortIndex
                    : lhs.date < rhs.date
            }

        let meals: [HomeDashboard.MealSummary] = plannedEntries.compactMap { entry in
            guard let dish = dishesById[entry.dishId] else { return nil }
            let result = coverageService.coverage(
                for: dish,
                servings: entry.totalServings,
                inventory: inventory
            )
            return HomeDashboard.MealSummary(
                id: entry.id,
                dishName: dish.trimmedName,
                slotTitle: entry.slotTitle,
                date: entry.date,
                servings: entry.totalServings,
                coverage: result.status,
                missingCount: result.missingCount
            )
        }

        let shoppingItems = shopping.items().filter { $0.status != .excluded }
        let purchased = shoppingItems.filter { $0.status == .purchased }.count

        let zoneSummaries: [HomeDashboard.ZoneSummary] = zones.zones(includeArchived: false)
            .map { zone in
                let inZone = inventory.filter { $0.zoneId == zone.id }
                let soon = inZone.filter { product in
                    let bucket = freshness.bucket(for: product, now: now)
                    return bucket == .review || bucket == .today || bucket == .nextThreeDays
                }
                return HomeDashboard.ZoneSummary(
                    id: zone.id,
                    name: zone.name,
                    type: zone.type,
                    productCount: inZone.count,
                    useSoonCount: soon.count,
                    capacity: zone.capacity
                )
            }

        let nextTask = prep.tasks()
            .filter { $0.status != .completed && $0.scheduledAt >= windowStart }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first

        return HomeDashboard(
            useSoon: useSoon,
            reviewCount: reviewCount,
            missingDateCount: missingDateCount,
            meals: meals,
            shoppingTotal: shoppingItems.count,
            shoppingPurchased: purchased,
            zones: zoneSummaries,
            nextPrepTask: nextTask,
            totalProducts: inventory.count
        )
    }
}
