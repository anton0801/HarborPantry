//
//  StorageZonesViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class StorageZonesViewModel: ObservableObject {
    struct ZoneRow: Identifiable, Hashable {
        let zone: StorageZone
        let productCount: Int
        let useSoonCount: Int

        var id: UUID { zone.id }

        var fillRatio: Double? {
            guard let capacity = zone.capacity, capacity > 0 else { return nil }
            return min(1, Double(productCount) / Double(capacity))
        }
    }

    @Published private(set) var rows: [ZoneRow] = []
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let profileUseCases: ProfileUseCases
    private let zoneRepository: StorageZoneRepository
    private let productRepository: ProductRepository
    private let inventoryUseCases: InventoryUseCases
    private let freshness: FreshnessService
    private let store: PantryStore
    private var cancellables = Set<AnyCancellable>()

    convenience init(dependencies: AppDependencies) {
        self.init(
            profileUseCases: dependencies.profileUseCases,
            zoneRepository: dependencies.zoneRepository,
            productRepository: dependencies.productRepository,
            inventoryUseCases: dependencies.inventoryUseCases,
            freshness: dependencies.freshnessService,
            store: dependencies.store
        )
    }

    init(
        profileUseCases: ProfileUseCases,
        zoneRepository: StorageZoneRepository,
        productRepository: ProductRepository,
        inventoryUseCases: InventoryUseCases,
        freshness: FreshnessService,
        store: PantryStore
    ) {
        self.profileUseCases = profileUseCases
        self.zoneRepository = zoneRepository
        self.productRepository = productRepository
        self.inventoryUseCases = inventoryUseCases
        self.freshness = freshness
        self.store = store

        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    func reload() {
        let products = productRepository.products(includeArchived: false)
        rows = zoneRepository.zones(includeArchived: true).map { zone in
            let inZone = products.filter { $0.zoneId == zone.id }
            let soon = inZone.filter { product in
                let bucket = freshness.bucket(for: product)
                return bucket == .review || bucket == .today || bucket == .nextThreeDays
            }
            return ZoneRow(zone: zone, productCount: inZone.count, useSoonCount: soon.count)
        }
    }

    func products(in zoneId: UUID) -> [Product] {
        productRepository.products(includeArchived: false)
            .filter { $0.zoneId == zoneId }
            .sorted { $0.trimmedName < $1.trimmedName }
    }

    var otherZones: [StorageZone] { zoneRepository.zones(includeArchived: false) }

    func delete(zone: StorageZone) async {
        do {
            try await profileUseCases.deleteZone(id: zone.id)
            infoMessage = "“\(zone.name)” was removed."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setArchived(_ archived: Bool, zone: StorageZone) async {
        do {
            try await profileUseCases.setZoneArchived(archived, id: zone.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves every product out of one zone so the zone can then be removed.
    func moveAllProducts(from source: UUID, to destination: UUID) async {
        let ids = products(in: source).map(\.id)
        guard !ids.isEmpty else { return }
        do {
            _ = try await inventoryUseCases.move(productIds: ids, to: destination)
            infoMessage = "Moved \(ids.count) product\(ids.count == 1 ? "" : "s")."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
