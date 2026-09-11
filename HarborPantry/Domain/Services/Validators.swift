//
//  Validators.swift
//  HarborPantry
//
//  Domain layer — form rules kept out of the views so every entry point
//  (manual add, import, shopping conversion) validates identically.
//

import Foundation

struct ProductDraft {
    var name: String = ""
    var category: ProductCategory = .other
    var quantityText: String = ""
    var unit: MeasurementUnit = .piece
    var zoneId: UUID?
    var purchaseDate: Date?
    var useByDate: Date?
    var openedDate: Date?
    var priceText: String = ""
    var photoFileName: String?
    var notes: String = ""
    var tags: [String] = []
}

struct ProductValidator {
    /// Non-blocking notes shown next to the form, e.g. an unusual date order.
    struct Result {
        var product: Product
        var warnings: [String]
    }

    func validate(draft: ProductDraft, existingId: UUID? = nil, createdAt: Date? = nil) throws -> Result {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw DomainError.validation("Product name is required.")
        }

        let normalizedQuantity = draft.quantityText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let quantity = Double(normalizedQuantity) else {
            throw DomainError.validation("Quantity must be a number.")
        }
        guard quantity > 0 else {
            throw DomainError.validation("Quantity must be greater than zero.")
        }

        guard let zoneId = draft.zoneId else {
            throw DomainError.validation("Choose a storage zone.")
        }

        var price: Double?
        let priceText = draft.priceText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        if !priceText.isEmpty {
            guard let parsed = Double(priceText), parsed >= 0 else {
                throw DomainError.validation("Price must be zero or more.")
            }
            price = parsed
        }

        // Date order is a *warning*, never a hard block — the user owns these
        // dates and may have a good reason for an unusual order.
        var warnings: [String] = []
        if let purchase = draft.purchaseDate, let useBy = draft.useByDate, useBy < purchase {
            warnings.append("Use-by date is earlier than the purchase date. Saved as entered.")
        }
        if let purchase = draft.purchaseDate, let opened = draft.openedDate, opened < purchase {
            warnings.append("Opened date is earlier than the purchase date. Saved as entered.")
        }
        if draft.useByDate == nil {
            warnings.append("No use-by date set. This product will appear under Missing Date.")
        }

        let product = Product(
            id: existingId ?? UUID(),
            name: name,
            category: draft.category,
            quantity: quantity.roundedToTwoDecimals,
            unit: draft.unit,
            zoneId: zoneId,
            purchaseDate: draft.purchaseDate,
            useByDate: draft.useByDate,
            openedDate: draft.openedDate,
            price: price,
            photoFileName: draft.photoFileName,
            notes: draft.notes,
            tags: draft.tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            createdAt: createdAt ?? Date(),
            updatedAt: Date()
        )

        return Result(product: product, warnings: warnings)
    }
}

struct ZoneValidator {
    func validate(name: String, type: StorageZoneType, capacityText: String, existing: [StorageZone], editingId: UUID?) throws -> (name: String, capacity: Int?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Zone name is required.")
        }

        let duplicate = existing.contains { zone in
            zone.id != editingId && zone.normalizedName == trimmed.lowercased()
        }
        guard !duplicate else {
            throw DomainError.conflict("A zone named “\(trimmed)” already exists.")
        }

        var capacity: Int?
        let capacityTrimmed = capacityText.trimmingCharacters(in: .whitespaces)
        if !capacityTrimmed.isEmpty {
            guard let parsed = Int(capacityTrimmed), parsed > 0 else {
                throw DomainError.validation("Capacity must be a whole number above zero.")
            }
            capacity = parsed
        }

        return (trimmed, capacity)
    }
}

struct DishValidator {
    func validate(
        name: String,
        servings: Int,
        ingredients: [DishIngredient]
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Dish name is required.")
        }
        guard servings > 0 else {
            throw DomainError.validation("Serving count must be greater than zero.")
        }
        if let bad = ingredients.first(where: { $0.trimmedName.isEmpty }) {
            _ = bad
            throw DomainError.validation("Every ingredient needs a name.")
        }
        if ingredients.contains(where: { $0.quantity <= 0 }) {
            throw DomainError.validation("Ingredient quantities must be greater than zero.")
        }
    }
}

struct ProfileValidator {
    func validate(householdName: String, peopleCount: Int) throws -> String {
        let trimmed = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("Household name is required.")
        }
        guard (PantryProfile.minimumPeople...PantryProfile.maximumPeople).contains(peopleCount) else {
            throw DomainError.validation(
                "People count must be between \(PantryProfile.minimumPeople) and \(PantryProfile.maximumPeople)."
            )
        }
        return trimmed
    }
}

struct QuantityValidator {
    /// Guards "use" style actions so a product can never go negative.
    func validateUse(amount: Double, available: Double, unit: MeasurementUnit) throws {
        guard amount > 0 else {
            throw DomainError.validation("Enter an amount greater than zero.")
        }
        guard amount <= available + 0.0001 else {
            throw DomainError.validation(
                "You only have \(available.quantityText) \(unit.shortLabel) left."
            )
        }
    }
}
