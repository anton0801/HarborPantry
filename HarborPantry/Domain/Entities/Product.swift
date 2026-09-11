//
//  Product.swift
//  HarborPantry
//
//  Domain layer — a single item the user keeps at home.
//

import Foundation

struct Product: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var category: ProductCategory
    var quantity: Double
    var unit: MeasurementUnit
    var zoneId: UUID
    var purchaseDate: Date?
    /// The date the *user* entered. Harbor Pantry never invents, estimates or
    /// validates this date against any food-safety standard.
    var useByDate: Date?
    var openedDate: Date?
    var price: Double?
    var photoFileName: String?
    var notes: String
    var tags: [String]
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: ProductCategory = .other,
        quantity: Double,
        unit: MeasurementUnit,
        zoneId: UUID,
        purchaseDate: Date? = nil,
        useByDate: Date? = nil,
        openedDate: Date? = nil,
        price: Double? = nil,
        photoFileName: String? = nil,
        notes: String = "",
        tags: [String] = [],
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.zoneId = zoneId
        self.purchaseDate = purchaseDate
        self.useByDate = useByDate
        self.openedDate = openedDate
        self.price = price
        self.photoFileName = photoFileName
        self.notes = notes
        self.tags = tags
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isOpened: Bool { openedDate != nil }
    var hasUseByDate: Bool { useByDate != nil }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether this product can be merged with `other` without losing meaning.
    /// Merging still requires an explicit confirmation from the user.
    func isMergeCandidate(with other: Product) -> Bool {
        guard id != other.id else { return false }
        guard unit == other.unit else { return false }
        guard zoneId == other.zoneId else { return false }
        return trimmedName.compare(other.trimmedName, options: .caseInsensitive) == .orderedSame
    }
}

// MARK: - Freshness bucket

/// A purely calendar-based grouping of the user's own dates.
///
/// This is *not* a safety assessment. `.review` only means "the date you wrote
/// down has passed" — the app never claims a product is spoiled or unsafe.
enum FreshnessBucket: String, Codable, CaseIterable, Hashable, Identifiable {
    case review
    case today
    case nextThreeDays
    case thisWeek
    case later
    case missingDate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .review: return "Review"
        case .today: return "Today"
        case .nextThreeDays: return "Next 3 Days"
        case .thisWeek: return "This Week"
        case .later: return "Later"
        case .missingDate: return "Missing Date"
        }
    }

    var symbolName: String {
        switch self {
        case .review: return "exclamationmark.circle"
        case .today: return "sun.max"
        case .nextThreeDays: return "calendar.badge.clock"
        case .thisWeek: return "calendar"
        case .later: return "clock.arrow.circlepath"
        case .missingDate: return "questionmark.circle"
        }
    }

    /// Order used everywhere the buckets are listed.
    static let displayOrder: [FreshnessBucket] = [
        .review, .today, .nextThreeDays, .thisWeek, .later, .missingDate
    ]
}

// MARK: - History

enum ProductHistoryKind: String, Codable, Hashable {
    case added
    case edited
    case used
    case discarded
    case moved
    case purchased
    case archived
    case restored
    case merged
    case leftover

    var displayName: String {
        switch self {
        case .added: return "Added"
        case .edited: return "Edited"
        case .used: return "Used"
        case .discarded: return "Discarded"
        case .moved: return "Moved"
        case .purchased: return "Purchased"
        case .archived: return "Archived"
        case .restored: return "Restored"
        case .merged: return "Merged"
        case .leftover: return "Leftover"
        }
    }

    var symbolName: String {
        switch self {
        case .added: return "plus.circle"
        case .edited: return "pencil.circle"
        case .used: return "checkmark.circle"
        case .discarded: return "trash.circle"
        case .moved: return "arrow.left.arrow.right.circle"
        case .purchased: return "cart.circle"
        case .archived: return "archivebox.circle"
        case .restored: return "arrow.uturn.backward.circle"
        case .merged: return "arrow.triangle.merge"
        case .leftover: return "takeoutbag.and.cup.and.straw"
        }
    }
}

struct ProductHistoryEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let productId: UUID?
    let productName: String
    let kind: ProductHistoryKind
    let quantityDelta: Double?
    let unit: MeasurementUnit?
    let category: ProductCategory?
    let note: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        productId: UUID?,
        productName: String,
        kind: ProductHistoryKind,
        quantityDelta: Double? = nil,
        unit: MeasurementUnit? = nil,
        category: ProductCategory? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.kind = kind
        self.quantityDelta = quantityDelta
        self.unit = unit
        self.category = category
        self.note = note
        self.createdAt = createdAt
    }
}
