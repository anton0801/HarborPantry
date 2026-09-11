//
//  InventoryViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class InventoryViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable, Hashable {
        case all
        case useSoon
        case frozen
        case opened
        case missingDate

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all: return "All"
            case .useSoon: return "Use Soon"
            case .frozen: return "Frozen"
            case .opened: return "Opened"
            case .missingDate: return "Missing Date"
            }
        }
    }

    @Published var searchText: String = ""
    @Published var filter: Filter = .all
    @Published var categoryFilter: ProductCategory?
    @Published private(set) var products: [Product] = []
    @Published private(set) var zonesById: [UUID: StorageZone] = [:]
    @Published private(set) var loadState: StoreLoadState = .idle

    @Published var isSelecting = false
    @Published var selection: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var toast: ToastState?
    @Published var mergePrompt: MergePrompt?

    struct MergePrompt: Identifiable {
        let id = UUID()
        let primary: Product
        let candidates: [Product]
    }

    private let productRepository: ProductRepository
    private let zoneRepository: StorageZoneRepository
    private let inventoryUseCases: InventoryUseCases
    private let freshness: FreshnessService
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            productRepository: dependencies.productRepository,
            zoneRepository: dependencies.zoneRepository,
            inventoryUseCases: dependencies.inventoryUseCases,
            freshness: dependencies.freshnessService,
            store: dependencies.store
        )
    }

    init(
        productRepository: ProductRepository,
        zoneRepository: StorageZoneRepository,
        inventoryUseCases: InventoryUseCases,
        freshness: FreshnessService,
        store: PantryStore
    ) {
        self.productRepository = productRepository
        self.zoneRepository = zoneRepository
        self.inventoryUseCases = inventoryUseCases
        self.freshness = freshness
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        store.$loadState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.loadState = state }
            .store(in: &cancellables)

        reload()
    }

    // MARK: - Data

    func reload() {
        products = productRepository.products(includeArchived: false)
        zonesById = Dictionary(
            uniqueKeysWithValues: zoneRepository.zones(includeArchived: true).map { ($0.id, $0) }
        )
    }

    var zones: [StorageZone] { zoneRepository.zones(includeArchived: false) }

    /// Categories that actually occur in the pantry — the chip row never shows
    /// a category the user has nothing in.
    var availableCategories: [ProductCategory] {
        let present = Set(products.map(\.category))
        return ProductCategory.allCases.filter { present.contains($0) }
    }

    var filteredProducts: [Product] {
        var result = products

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { product in
                product.trimmedName.lowercased().contains(query)
                    || product.tags.contains { $0.lowercased().contains(query) }
                    || product.notes.lowercased().contains(query)
            }
        }

        if let category = categoryFilter {
            result = result.filter { $0.category == category }
        }

        switch filter {
        case .all:
            break
        case .useSoon:
            result = result.filter { product in
                let bucket = freshness.bucket(for: product)
                return bucket == .review || bucket == .today || bucket == .nextThreeDays
            }
        case .frozen:
            let freezerIds = Set(zonesById.values.filter { $0.type == .freezer }.map(\.id))
            result = result.filter { freezerIds.contains($0.zoneId) }
        case .opened:
            result = result.filter(\.isOpened)
        case .missingDate:
            result = result.filter { !$0.hasUseByDate }
        }

        return result.sorted { lhs, rhs in
            let lb = freshness.bucket(for: lhs)
            let rb = freshness.bucket(for: rhs)
            if lb != rb {
                let order = FreshnessBucket.displayOrder
                return (order.firstIndex(of: lb) ?? 0) < (order.firstIndex(of: rb) ?? 0)
            }
            // Inside a bucket the nearest date comes first; undated rows fall
            // back to alphabetical order.
            switch (lhs.useByDate, rhs.useByDate) {
            case let (left?, right?) where left != right:
                return left < right
            default:
                return lhs.trimmedName.localizedCaseInsensitiveCompare(rhs.trimmedName) == .orderedAscending
            }
        }
    }

    var isEmptyPantry: Bool { products.isEmpty }

    func zoneName(for product: Product) -> String {
        zonesById[product.zoneId]?.name ?? "Unassigned"
    }

    func bucket(for product: Product) -> FreshnessBucket {
        freshness.bucket(for: product)
    }

    func daysText(for product: Product) -> String {
        guard let days = freshness.daysRemaining(for: product) else { return "No date" }
        return HarborFormat.relativeDays(days)
    }

    // MARK: - Selection

    func toggleSelection(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    func clearSelection() {
        selection.removeAll()
        isSelecting = false
    }

    // MARK: - Actions

    func markUsed(_ product: Product) async {
        do {
            let token = try await inventoryUseCases.useQuantity(
                productId: product.id,
                amount: product.quantity,
                note: "Marked used from Inventory"
            )
            toast = ToastState(message: "\(product.trimmedName) marked used.") { [weak self] in
                Task { await self?.undo(token) }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undo(_ token: InventoryUndoToken) async {
        do {
            try await inventoryUseCases.undo(token)
            toast = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(to zoneId: UUID) async {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        do {
            let tokens = try await inventoryUseCases.move(productIds: ids, to: zoneId)
            let zoneName = zonesById[zoneId]?.name ?? "the new zone"
            toast = ToastState(message: "Moved \(tokens.count) product\(tokens.count == 1 ? "" : "s") to \(zoneName).") { [weak self] in
                Task {
                    for token in tokens { await self?.undo(token) }
                }
            }
            clearSelection()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveSelected() async {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        do {
            try await inventoryUseCases.setArchived(true, productIds: ids)
            toast = ToastState(message: "Archived \(ids.count) product\(ids.count == 1 ? "" : "s").")
            clearSelection()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelected() async {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        do {
            try await inventoryUseCases.delete(productIds: ids)
            toast = ToastState(message: "Deleted \(ids.count) product\(ids.count == 1 ? "" : "s").")
            clearSelection()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Offers a merge only when duplicates genuinely line up; the user still
    /// has to confirm.
    func checkForMerge(_ product: Product) {
        let candidates = inventoryUseCases.mergeCandidates(for: product)
        guard !candidates.isEmpty else {
            errorMessage = "No other row matches “\(product.trimmedName)” with the same unit and zone."
            return
        }
        mergePrompt = MergePrompt(primary: product, candidates: candidates)
    }

    func confirmMerge(_ prompt: MergePrompt) async {
        do {
            _ = try await inventoryUseCases.merge(
                primaryId: prompt.primary.id,
                otherIds: prompt.candidates.map(\.id)
            )
            toast = ToastState(message: "Merged into \(prompt.primary.trimmedName).")
            mergePrompt = nil
            errorMessage = nil
        } catch {
            mergePrompt = nil
            errorMessage = error.localizedDescription
        }
    }
}
