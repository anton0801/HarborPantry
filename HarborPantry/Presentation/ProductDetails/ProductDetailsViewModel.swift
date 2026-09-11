//
//  ProductDetailsViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class ProductDetailsViewModel: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var zone: StorageZone?
    @Published private(set) var history: [ProductHistoryEntry] = []
    @Published private(set) var linkedDishes: [Dish] = []
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published var useAmountText: String = ""

    private let productId: UUID
    private let inventoryUseCases: InventoryUseCases
    private let shoppingUseCases: ShoppingUseCases
    private let productRepository: ProductRepository
    private let zoneRepository: StorageZoneRepository
    private let historyRepository: HistoryRepository
    private let dishRepository: DishRepository
    private let freshness: FreshnessService
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies, productId: UUID) {
        self.init(
            productId: productId,
            inventoryUseCases: dependencies.inventoryUseCases,
            shoppingUseCases: dependencies.shoppingUseCases,
            productRepository: dependencies.productRepository,
            zoneRepository: dependencies.zoneRepository,
            historyRepository: dependencies.historyRepository,
            dishRepository: dependencies.dishRepository,
            freshness: dependencies.freshnessService,
            store: dependencies.store
        )
    }

    init(
        productId: UUID,
        inventoryUseCases: InventoryUseCases,
        shoppingUseCases: ShoppingUseCases,
        productRepository: ProductRepository,
        zoneRepository: StorageZoneRepository,
        historyRepository: HistoryRepository,
        dishRepository: DishRepository,
        freshness: FreshnessService,
        store: PantryStore
    ) {
        self.productId = productId
        self.inventoryUseCases = inventoryUseCases
        self.shoppingUseCases = shoppingUseCases
        self.productRepository = productRepository
        self.zoneRepository = zoneRepository
        self.historyRepository = historyRepository
        self.dishRepository = dishRepository
        self.freshness = freshness
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        product = productRepository.product(id: productId)
        zone = product.flatMap { zoneRepository.zone(id: $0.zoneId) }
        history = historyRepository.entries(forProduct: productId)
        if let product = product {
            linkedDishes = dishRepository.dishes(includeArchived: false).filter { dish in
                dish.ingredients.contains { ingredient in
                    ingredient.linkedProductId == product.id
                        || ingredient.trimmedName.compare(
                            product.trimmedName,
                            options: .caseInsensitive
                        ) == .orderedSame
                }
            }
        } else {
            linkedDishes = []
        }
    }

    var zones: [StorageZone] { zoneRepository.zones(includeArchived: false) }

    var bucket: FreshnessBucket? {
        product.map { freshness.bucket(for: $0) }
    }

    var daysText: String? {
        guard let product = product else { return nil }
        guard let days = freshness.daysRemaining(for: product) else { return nil }
        return HarborFormat.relativeDays(days)
    }

    /// Parsed amount from the "Use Quantity" field.
    var parsedUseAmount: Double? {
        Double(useAmountText.replacingOccurrences(of: ",", with: "."))
    }

    var canUse: Bool {
        guard let product = product, let amount = parsedUseAmount else { return false }
        return amount > 0 && amount <= product.quantity + 0.0001
    }

    // MARK: - Actions

    func useQuantity() async {
        guard let product = product, let amount = parsedUseAmount else { return }
        do {
            let token = try await inventoryUseCases.useQuantity(
                productId: product.id,
                amount: amount,
                note: "Used from Product Details"
            )
            useAmountText = ""
            toast = ToastState(message: token.actionLabel) { [weak self] in
                Task { await self?.undo(token) }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardQuantity() async {
        guard let product = product, let amount = parsedUseAmount else { return }
        do {
            let token = try await inventoryUseCases.discardQuantity(
                productId: product.id,
                amount: amount,
                note: "Discarded from Product Details"
            )
            useAmountText = ""
            toast = ToastState(message: token.actionLabel) { [weak self] in
                Task { await self?.undo(token) }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func undo(_ token: InventoryUndoToken) async {
        do {
            try await inventoryUseCases.undo(token)
            toast = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(to zoneId: UUID) async {
        guard let product = product else { return }
        do {
            let tokens = try await inventoryUseCases.move(productIds: [product.id], to: zoneId)
            if let token = tokens.first {
                toast = ToastState(message: token.actionLabel) { [weak self] in
                    Task { await self?.undo(token) }
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func duplicate() async {
        guard let product = product else { return }
        do {
            let copy = try await inventoryUseCases.duplicate(product)
            toast = ToastState(message: "Created “\(copy.trimmedName)”.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setArchived(_ archived: Bool) async {
        guard let product = product else { return }
        do {
            try await inventoryUseCases.setArchived(archived, productIds: [product.id])
            toast = ToastState(message: archived ? "Moved to archive." : "Restored from archive.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async -> Bool {
        guard let product = product else { return false }
        do {
            try await inventoryUseCases.delete(productIds: [product.id])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Puts more of this product onto the shopping list.
    func addToShopping(quantity: Double) async {
        guard let product = product else { return }
        do {
            try await shoppingUseCases.addCustomItem(
                name: product.trimmedName,
                category: product.category,
                quantity: quantity,
                unit: product.unit,
                store: "",
                estimatedPrice: product.price,
                shopper: ""
            )
            toast = ToastState(message: "Added to the shopping list.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
