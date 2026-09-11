//
//  InventoryUseCases.swift
//  HarborPantry
//
//  Domain layer — every write to inventory goes through here so that quantity
//  changes and history entries can never drift apart.
//

import Foundation

/// Everything needed to undo a single inventory action.
struct InventoryUndoToken: Hashable, Identifiable {
    let id: UUID
    let productId: UUID
    let previousQuantity: Double
    let previousZoneId: UUID
    let previousArchived: Bool
    let historyEntryId: UUID
    let actionLabel: String
}

@MainActor
struct InventoryUseCases {
    private let products: ProductRepository
    private let history: HistoryRepository
    private let zones: StorageZoneRepository
    private let photos: PhotoStoring
    private let quantityValidator = QuantityValidator()

    init(
        products: ProductRepository,
        history: HistoryRepository,
        zones: StorageZoneRepository,
        photos: PhotoStoring
    ) {
        self.products = products
        self.history = history
        self.zones = zones
        self.photos = photos
    }

    // MARK: - Create / update

    func addProduct(_ product: Product) async throws {
        try await products.add(product)
        try await history.record(
            ProductHistoryEntry(
                productId: product.id,
                productName: product.trimmedName,
                kind: .added,
                quantityDelta: product.quantity,
                unit: product.unit,
                category: product.category,
                note: zoneName(product.zoneId).map { "Stored in \($0)" } ?? ""
            )
        )
    }

    func updateProduct(_ product: Product, previous: Product) async throws {
        try await products.update(product)

        var changes: [String] = []
        if product.trimmedName != previous.trimmedName { changes.append("name") }
        if product.quantity != previous.quantity { changes.append("quantity") }
        if product.unit != previous.unit { changes.append("unit") }
        if product.useByDate != previous.useByDate { changes.append("use-by date") }
        if product.zoneId != previous.zoneId { changes.append("storage zone") }

        try await history.record(
            ProductHistoryEntry(
                productId: product.id,
                productName: product.trimmedName,
                kind: .edited,
                unit: product.unit,
                category: product.category,
                note: changes.isEmpty ? "Details updated" : "Updated \(changes.joined(separator: ", "))"
            )
        )
    }

    func duplicate(_ product: Product) async throws -> Product {
        let copy = Product(
            name: "\(product.trimmedName) copy",
            category: product.category,
            quantity: product.quantity,
            unit: product.unit,
            zoneId: product.zoneId,
            purchaseDate: product.purchaseDate,
            useByDate: product.useByDate,
            openedDate: product.openedDate,
            price: product.price,
            photoFileName: nil,
            notes: product.notes,
            tags: product.tags
        )
        try await addProduct(copy)
        return copy
    }

    // MARK: - Quantity actions

    /// Consumes part (or all) of a product. Records exactly one history entry
    /// and hands back a token so the screen can offer Undo.
    @discardableResult
    func useQuantity(
        productId: UUID,
        amount: Double,
        note: String = ""
    ) async throws -> InventoryUndoToken {
        guard let product = products.product(id: productId) else {
            throw DomainError.notFound("That product no longer exists.")
        }
        try quantityValidator.validateUse(
            amount: amount,
            available: product.quantity,
            unit: product.unit
        )

        var updated = product
        updated.quantity = (product.quantity - amount).roundedToTwoDecimals
        updated.updatedAt = Date()
        try await products.update(updated)

        let entry = ProductHistoryEntry(
            productId: product.id,
            productName: product.trimmedName,
            kind: .used,
            quantityDelta: -amount,
            unit: product.unit,
            category: product.category,
            note: note
        )
        try await history.record(entry)

        return InventoryUndoToken(
            id: UUID(),
            productId: product.id,
            previousQuantity: product.quantity,
            previousZoneId: product.zoneId,
            previousArchived: product.isArchived,
            historyEntryId: entry.id,
            actionLabel: "Used \(amount.quantityText) \(product.unit.shortLabel)"
        )
    }

    @discardableResult
    func discardQuantity(
        productId: UUID,
        amount: Double,
        note: String = ""
    ) async throws -> InventoryUndoToken {
        guard let product = products.product(id: productId) else {
            throw DomainError.notFound("That product no longer exists.")
        }
        try quantityValidator.validateUse(
            amount: amount,
            available: product.quantity,
            unit: product.unit
        )

        var updated = product
        updated.quantity = (product.quantity - amount).roundedToTwoDecimals
        updated.updatedAt = Date()
        try await products.update(updated)

        let entry = ProductHistoryEntry(
            productId: product.id,
            productName: product.trimmedName,
            kind: .discarded,
            quantityDelta: -amount,
            unit: product.unit,
            category: product.category,
            note: note
        )
        try await history.record(entry)

        return InventoryUndoToken(
            id: UUID(),
            productId: product.id,
            previousQuantity: product.quantity,
            previousZoneId: product.zoneId,
            previousArchived: product.isArchived,
            historyEntryId: entry.id,
            actionLabel: "Discarded \(amount.quantityText) \(product.unit.shortLabel)"
        )
    }

    /// Restores the product to its pre-action state and removes the history
    /// entry the action created, so Undo leaves no trace.
    func undo(_ token: InventoryUndoToken) async throws {
        guard var product = products.product(id: token.productId) else {
            throw DomainError.notFound("That product no longer exists.")
        }
        product.quantity = token.previousQuantity
        product.zoneId = token.previousZoneId
        product.isArchived = token.previousArchived
        product.updatedAt = Date()
        try await products.update(product)
        try await history.remove(id: token.historyEntryId)
    }

    // MARK: - Movement and lifecycle

    @discardableResult
    func move(productIds: [UUID], to zoneId: UUID) async throws -> [InventoryUndoToken] {
        guard let zone = zones.zone(id: zoneId) else {
            throw DomainError.notFound("That storage zone no longer exists.")
        }

        var tokens: [InventoryUndoToken] = []
        for id in productIds {
            guard var product = products.product(id: id) else { continue }
            let previousZone = product.zoneId
            guard previousZone != zoneId else { continue }

            let fromName = zoneName(previousZone) ?? "another zone"
            product.zoneId = zoneId
            product.updatedAt = Date()
            try await products.update(product)

            let entry = ProductHistoryEntry(
                productId: product.id,
                productName: product.trimmedName,
                kind: .moved,
                unit: product.unit,
                category: product.category,
                note: "Moved from \(fromName) to \(zone.name)"
            )
            try await history.record(entry)

            tokens.append(
                InventoryUndoToken(
                    id: UUID(),
                    productId: product.id,
                    previousQuantity: product.quantity,
                    previousZoneId: previousZone,
                    previousArchived: product.isArchived,
                    historyEntryId: entry.id,
                    actionLabel: "Moved to \(zone.name)"
                )
            )
        }
        return tokens
    }

    func setArchived(_ archived: Bool, productIds: [UUID]) async throws {
        for id in productIds {
            guard var product = products.product(id: id) else { continue }
            product.isArchived = archived
            product.updatedAt = Date()
            try await products.update(product)
            try await history.record(
                ProductHistoryEntry(
                    productId: product.id,
                    productName: product.trimmedName,
                    kind: archived ? .archived : .restored,
                    unit: product.unit,
                    category: product.category
                )
            )
        }
    }

    func delete(productIds: [UUID]) async throws {
        let doomed = productIds.compactMap { products.product(id: $0) }
        try await products.delete(ids: productIds)
        for product in doomed {
            if let photo = product.photoFileName {
                photos.delete(named: photo)
            }
        }
    }

    // MARK: - Merging

    /// Products only merge when the user asks and the units already agree.
    func merge(primaryId: UUID, otherIds: [UUID]) async throws -> Product {
        guard var primary = products.product(id: primaryId) else {
            throw DomainError.notFound("That product no longer exists.")
        }

        var mergedNames: [String] = []
        var total = primary.quantity

        for id in otherIds {
            guard let candidate = products.product(id: id) else { continue }
            guard candidate.unit == primary.unit else {
                throw DomainError.conflict(
                    "“\(candidate.trimmedName)” uses \(candidate.unit.shortLabel) while “\(primary.trimmedName)” uses \(primary.unit.shortLabel). Change one of them first."
                )
            }
            total += candidate.quantity
            mergedNames.append(candidate.trimmedName)
            // Keep the earliest user date so nothing silently gets a longer life.
            if let candidateDate = candidate.useByDate {
                primary.useByDate = min(primary.useByDate ?? candidateDate, candidateDate)
            }
        }

        guard !mergedNames.isEmpty else { return primary }

        primary.quantity = total.roundedToTwoDecimals
        primary.updatedAt = Date()
        try await products.update(primary)
        try await products.delete(ids: otherIds)
        try await history.record(
            ProductHistoryEntry(
                productId: primary.id,
                productName: primary.trimmedName,
                kind: .merged,
                quantityDelta: (total - (total - primary.quantity)).roundedToTwoDecimals,
                unit: primary.unit,
                category: primary.category,
                note: "Merged \(mergedNames.count) row\(mergedNames.count == 1 ? "" : "s")"
            )
        )
        return primary
    }

    /// Candidates the user could merge with `product` — same name, same unit,
    /// same zone. Nothing merges without an explicit confirmation.
    func mergeCandidates(for product: Product) -> [Product] {
        products.products(includeArchived: false)
            .filter { $0.isMergeCandidate(with: product) }
    }

    private func zoneName(_ id: UUID) -> String? {
        zones.zone(id: id)?.name
    }
}
