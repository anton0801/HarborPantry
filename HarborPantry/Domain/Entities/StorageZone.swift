//
//  StorageZone.swift
//  HarborPantry
//
//  Domain layer — where a product physically lives.
//

import Foundation

enum StorageZoneType: String, Codable, CaseIterable, Hashable, Identifiable {
    case refrigerator
    case freezer
    case pantry
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .refrigerator: return "Refrigerator"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .refrigerator: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        case .custom: return "square.stack.3d.up"
        }
    }
}

struct StorageZone: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var type: StorageZoneType
    /// An organisational hint only — the app performs no temperature or
    /// capacity enforcement of any kind.
    var capacity: Int?
    var note: String
    var isArchived: Bool
    var sortIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: StorageZoneType,
        capacity: Int? = nil,
        note: String = "",
        isArchived: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.capacity = capacity
        self.note = note
        self.isArchived = isArchived
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The three zones every new pantry starts with. The user can rename,
    /// extend or remove them afterwards.
    static func defaultZones() -> [StorageZone] {
        [
            StorageZone(name: "Refrigerator", type: .refrigerator, sortIndex: 0),
            StorageZone(name: "Freezer", type: .freezer, sortIndex: 1),
            StorageZone(name: "Pantry", type: .pantry, sortIndex: 2)
        ]
    }
}
