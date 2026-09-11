//
//  ProductFormViewModel.swift
//  HarborPantry
//

import SwiftUI
import Combine

@MainActor
final class ProductFormViewModel: ObservableObject {
    enum Mode: Equatable {
        case create
        case edit(UUID)

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    @Published var draft = ProductDraft()
    @Published private(set) var zones: [StorageZone] = []
    @Published private(set) var warnings: [String] = []
    @Published var errorMessage: String?
    @Published private(set) var isSaving = false
    @Published private(set) var photoData: Data?

    private let mode: Mode
    private let inventoryUseCases: InventoryUseCases
    private let productRepository: ProductRepository
    private let zoneRepository: StorageZoneRepository
    private let profileRepository: ProfileRepository
    private let photoStore: PhotoStoring
    private let validator = ProductValidator()
    private var existingProduct: Product?

    /// Key under which an unsaved new-product draft is parked when the form is
    /// dismissed, so the work is not silently lost.
    private static let draftKey = "harbor.product.draft"

    convenience init(dependencies: AppDependencies, mode: Mode) {
        self.init(
            mode: mode,
            inventoryUseCases: dependencies.inventoryUseCases,
            productRepository: dependencies.productRepository,
            zoneRepository: dependencies.zoneRepository,
            profileRepository: dependencies.profileRepository,
            photoStore: dependencies.photoStore
        )
    }

    init(
        mode: Mode,
        inventoryUseCases: InventoryUseCases,
        productRepository: ProductRepository,
        zoneRepository: StorageZoneRepository,
        profileRepository: ProfileRepository,
        photoStore: PhotoStoring
    ) {
        self.mode = mode
        self.inventoryUseCases = inventoryUseCases
        self.productRepository = productRepository
        self.zoneRepository = zoneRepository
        self.profileRepository = profileRepository
        self.photoStore = photoStore

        zones = zoneRepository.zones(includeArchived: false)

        switch mode {
        case .create:
            let profile = profileRepository.currentProfile()
            draft.unit = profile.defaultUnit
            draft.zoneId = zones.first?.id
            draft.purchaseDate = Date()
            restoreDraftIfAvailable()
        case let .edit(id):
            if let product = productRepository.product(id: id) {
                existingProduct = product
                draft = ProductDraft(
                    name: product.name,
                    category: product.category,
                    quantityText: product.quantity.quantityText,
                    unit: product.unit,
                    zoneId: product.zoneId,
                    purchaseDate: product.purchaseDate,
                    useByDate: product.useByDate,
                    openedDate: product.openedDate,
                    priceText: product.price.map { $0.quantityText } ?? "",
                    photoFileName: product.photoFileName,
                    notes: product.notes,
                    tags: product.tags
                )
                if let fileName = product.photoFileName {
                    photoData = photoStore.loadData(named: fileName)
                }
            }
        }
    }

    var isEditing: Bool { mode.isEditing }

    var title: String { isEditing ? "Edit Product" : "Add Product" }

    var currency: CurrencyOption { profileRepository.currentProfile().currency }

    var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.quantityText.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.zoneId != nil
            && !isSaving
    }

    var hasUnsavedContent: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            || !draft.quantityText.trimmingCharacters(in: .whitespaces).isEmpty
            || !draft.notes.isEmpty
    }

    // MARK: - Photo

    func attachPhoto(_ data: Data) {
        do {
            // Replace any previous file so orphans do not accumulate.
            if let existing = draft.photoFileName {
                photoStore.delete(named: existing)
            }
            draft.photoFileName = try photoStore.save(imageData: data)
            photoData = data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePhoto() {
        if let existing = draft.photoFileName {
            photoStore.delete(named: existing)
        }
        draft.photoFileName = nil
        photoData = nil
    }

    // MARK: - Validation preview

    /// Recomputes the non-blocking warnings shown under the date fields.
    func refreshWarnings() {
        guard let result = try? validator.validate(
            draft: draft,
            existingId: existingProduct?.id,
            createdAt: existingProduct?.createdAt
        ) else {
            warnings = []
            return
        }
        warnings = result.warnings
    }

    // MARK: - Save

    /// Returns the saved product on success.
    func save() async -> Product? {
        isSaving = true
        defer { isSaving = false }
        do {
            let result = try validator.validate(
                draft: draft,
                existingId: existingProduct?.id,
                createdAt: existingProduct?.createdAt
            )
            warnings = result.warnings

            if let previous = existingProduct {
                try await inventoryUseCases.updateProduct(result.product, previous: previous)
            } else {
                try await inventoryUseCases.addProduct(result.product)
            }
            clearStoredDraft()
            errorMessage = nil
            return result.product
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Saves and resets the form so the next item can be typed straight away.
    func saveAndAddAnother() async -> Bool {
        guard await save() != nil else { return false }
        let keepZone = draft.zoneId
        let keepUnit = draft.unit
        let keepCategory = draft.category
        draft = ProductDraft()
        draft.zoneId = keepZone
        draft.unit = keepUnit
        draft.category = keepCategory
        draft.purchaseDate = Date()
        photoData = nil
        warnings = []
        return true
    }

    func delete() async -> Bool {
        guard let product = existingProduct else { return false }
        do {
            try await inventoryUseCases.delete(productIds: [product.id])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Draft persistence

    /// Parks an unfinished new product so closing the sheet does not lose it.
    func storeDraftIfNeeded() {
        guard !isEditing, hasUnsavedContent else { return }
        let payload: [String: Any] = [
            "name": draft.name,
            "category": draft.category.rawValue,
            "quantity": draft.quantityText,
            "unit": draft.unit.rawValue,
            "notes": draft.notes,
            "tags": draft.tags
        ]
        UserDefaults.standard.set(payload, forKey: Self.draftKey)
    }

    func clearStoredDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    private func restoreDraftIfAvailable() {
        guard let payload = UserDefaults.standard.dictionary(forKey: Self.draftKey) else { return }
        draft.name = payload["name"] as? String ?? ""
        draft.quantityText = payload["quantity"] as? String ?? ""
        draft.notes = payload["notes"] as? String ?? ""
        draft.tags = payload["tags"] as? [String] ?? []
        if let raw = payload["category"] as? String, let category = ProductCategory(rawValue: raw) {
            draft.category = category
        }
        if let raw = payload["unit"] as? String, let unit = MeasurementUnit(rawValue: raw) {
            draft.unit = unit
        }
    }
}

