//
//  ShoppingListViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class ShoppingListViewModel: ObservableObject {
    enum Grouping: String, CaseIterable, Identifiable, Hashable {
        case category
        case store

        var id: String { rawValue }
        var displayName: String { self == .category ? "By Category" : "By Store" }
    }

    struct Group: Identifiable, Hashable {
        let id: String
        let title: String
        let items: [ShoppingItem]
    }

    @Published var grouping: Grouping = .category
    @Published var showPurchased = true
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var zones: [StorageZone] = []
    @Published private(set) var currency: CurrencyOption = .fallback
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published var purchasingItem: ShoppingItem?
    @Published var excludingItem: ShoppingItem?

    private let shoppingUseCases: ShoppingUseCases
    private let shoppingRepository: ShoppingRepository
    private let mealPlanRepository: MealPlanRepository
    private let zoneRepository: StorageZoneRepository
    private let profileRepository: ProfileRepository
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            shoppingUseCases: dependencies.shoppingUseCases,
            shoppingRepository: dependencies.shoppingRepository,
            mealPlanRepository: dependencies.mealPlanRepository,
            zoneRepository: dependencies.zoneRepository,
            profileRepository: dependencies.profileRepository,
            store: dependencies.store
        )
    }

    init(
        shoppingUseCases: ShoppingUseCases,
        shoppingRepository: ShoppingRepository,
        mealPlanRepository: MealPlanRepository,
        zoneRepository: StorageZoneRepository,
        profileRepository: ProfileRepository,
        store: PantryStore
    ) {
        self.shoppingUseCases = shoppingUseCases
        self.shoppingRepository = shoppingRepository
        self.mealPlanRepository = mealPlanRepository
        self.zoneRepository = zoneRepository
        self.profileRepository = profileRepository
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        items = shoppingRepository.items()
        zones = zoneRepository.zones(includeArchived: false)
        currency = profileRepository.currentProfile().currency
    }

    var isEmpty: Bool { items.isEmpty }

    var pendingItems: [ShoppingItem] { items.filter { $0.status == .pending } }
    var purchasedItems: [ShoppingItem] { items.filter { $0.status == .purchased } }
    var excludedItems: [ShoppingItem] { items.filter { $0.status == .excluded } }

    var progress: Double {
        let relevant = items.filter { $0.status != .excluded }
        guard !relevant.isEmpty else { return 0 }
        return Double(relevant.filter { $0.status == .purchased }.count) / Double(relevant.count)
    }

    var estimatedTotal: Double {
        items
            .filter { $0.status == .pending }
            .compactMap(\.estimatedPrice)
            .reduce(0, +)
    }

    var actualTotal: Double {
        items
            .filter { $0.status == .purchased }
            .compactMap(\.actualPrice)
            .reduce(0, +)
    }

    var groups: [Group] {
        let visible = items.filter { item in
            switch item.status {
            case .pending: return true
            case .purchased: return showPurchased
            case .excluded: return false
            }
        }

        switch grouping {
        case .category:
            let buckets = Dictionary(grouping: visible, by: \.category)
            return buckets
                .map { category, rows in
                    Group(
                        id: category.rawValue,
                        title: category.displayName,
                        items: rows.sorted { $0.trimmedName < $1.trimmedName }
                    )
                }
                .sorted { $0.title < $1.title }
        case .store:
            let buckets = Dictionary(grouping: visible, by: \.storeLabel)
            return buckets
                .map { store, rows in
                    Group(
                        id: store,
                        title: store,
                        items: rows.sorted { $0.trimmedName < $1.trimmedName }
                    )
                }
                .sorted { $0.title < $1.title }
        }
    }

    // MARK: - Actions

    /// Regenerates automatic rows from the current plan.
    func syncFromPlan() async {
        do {
            let added = try await shoppingUseCases.syncAutomaticItems(for: mealPlanRepository.entries())
            toast = ToastState(
                message: added == 0
                    ? "The list already matches your plan."
                    : "Added \(added) item\(added == 1 ? "" : "s") from your meal plan."
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addCustomItem(
        name: String,
        category: ProductCategory,
        quantity: Double,
        unit: MeasurementUnit,
        store: String,
        estimatedPrice: Double?,
        shopper: String
    ) async {
        do {
            try await shoppingUseCases.addCustomItem(
                name: name,
                category: category,
                quantity: quantity,
                unit: unit,
                store: store,
                estimatedPrice: estimatedPrice,
                shopper: shopper
            )
            toast = ToastState(message: "Added to the list.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmPurchase(item: ShoppingItem, confirmation: PurchaseConfirmation) async {
        do {
            let token = try await shoppingUseCases.markPurchased(
                itemId: item.id,
                confirmation: confirmation
            )
            toast = ToastState(message: token.label) { [weak self] in
                Task {
                    try? await self?.shoppingUseCases.undoPurchase(token)
                    self?.toast = nil
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exclude(item: ShoppingItem, reason: String) async {
        do {
            try await shoppingUseCases.excludeAutomaticItem(itemId: item.id, reason: reason)
            toast = ToastState(message: "Excluded “\(item.trimmedName)”.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(item: ShoppingItem) async {
        do {
            try await shoppingUseCases.restore(itemId: item.id)
            toast = ToastState(message: "Back on the list.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(item: ShoppingItem) async {
        do {
            try await shoppingUseCases.delete(itemId: item.id)
            toast = ToastState(message: "Removed from the list.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setStore(item: ShoppingItem, store: String) async {
        do {
            try await shoppingUseCases.setStore(itemIds: [item.id], store: store)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
