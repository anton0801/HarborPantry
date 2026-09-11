//
//  PantrySnapshot.swift
//  HarborPantry
//
//  Data layer — the whole local database in one Codable value.
//

import Foundation

struct PantrySnapshot: Codable, Hashable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var profile: PantryProfile
    var settings: AppSettings
    var zones: [StorageZone]
    var products: [Product]
    var history: [ProductHistoryEntry]
    var dishes: [Dish]
    var mealEntries: [MealPlanEntry]
    var shoppingItems: [ShoppingItem]
    var prepTasks: [PrepTask]
    var leftovers: [Leftover]
    var exportedAt: Date?

    init(
        schemaVersion: Int = PantrySnapshot.currentSchemaVersion,
        profile: PantryProfile = PantryProfile(),
        settings: AppSettings = AppSettings(),
        zones: [StorageZone] = StorageZone.defaultZones(),
        products: [Product] = [],
        history: [ProductHistoryEntry] = [],
        dishes: [Dish] = [],
        mealEntries: [MealPlanEntry] = [],
        shoppingItems: [ShoppingItem] = [],
        prepTasks: [PrepTask] = [],
        leftovers: [Leftover] = [],
        exportedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.settings = settings
        self.zones = zones
        self.products = products
        self.history = history
        self.dishes = dishes
        self.mealEntries = mealEntries
        self.shoppingItems = shoppingItems
        self.prepTasks = prepTasks
        self.leftovers = leftovers
        self.exportedAt = exportedAt
    }

    /// A brand-new pantry: default zones only, and deliberately no demo
    /// products, dishes or shopping rows.
    static var empty: PantrySnapshot { PantrySnapshot() }

    // Older files may lack keys added later; decode defensively so a partial
    // file never costs the user their whole pantry.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? PantrySnapshot.currentSchemaVersion
        profile = try container.decodeIfPresent(PantryProfile.self, forKey: .profile) ?? PantryProfile()
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        zones = try container.decodeIfPresent([StorageZone].self, forKey: .zones) ?? []
        products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
        history = try container.decodeIfPresent([ProductHistoryEntry].self, forKey: .history) ?? []
        dishes = try container.decodeIfPresent([Dish].self, forKey: .dishes) ?? []
        mealEntries = try container.decodeIfPresent([MealPlanEntry].self, forKey: .mealEntries) ?? []
        shoppingItems = try container.decodeIfPresent([ShoppingItem].self, forKey: .shoppingItems) ?? []
        prepTasks = try container.decodeIfPresent([PrepTask].self, forKey: .prepTasks) ?? []
        leftovers = try container.decodeIfPresent([Leftover].self, forKey: .leftovers) ?? []
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt)
    }
}
