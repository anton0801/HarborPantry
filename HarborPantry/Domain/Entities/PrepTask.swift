//
//  PrepTask.swift
//  HarborPantry
//
//  Domain layer — timeline tasks and post-meal leftovers.
//

import Foundation

enum PrepTaskKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case thaw
    case prep
    case cook
    case serve
    case quick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thaw: return "Thaw"
        case .prep: return "Prep"
        case .cook: return "Cook"
        case .serve: return "Serve"
        case .quick: return "Quick Task"
        }
    }

    var symbolName: String {
        switch self {
        case .thaw: return "snowflake"
        case .prep: return "hand.raised"
        case .cook: return "flame"
        case .serve: return "fork.knife"
        case .quick: return "bolt"
        }
    }
}

enum PrepTaskStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case inProgress
    case completed
    case delayed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .delayed: return "Delayed"
        }
    }
}

struct PrepTask: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var kind: PrepTaskKind
    var scheduledAt: Date
    var durationMinutes: Int
    /// Task that must finish before this one. Shifting a dependency only
    /// *suggests* a new time; the user confirms the move.
    var dependencyId: UUID?
    var linkedDishId: UUID?
    var linkedProductId: UUID?
    var status: PrepTaskStatus
    var note: String
    var startedAt: Date?
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        kind: PrepTaskKind = .prep,
        scheduledAt: Date,
        durationMinutes: Int = 15,
        dependencyId: UUID? = nil,
        linkedDishId: UUID? = nil,
        linkedProductId: UUID? = nil,
        status: PrepTaskStatus = .pending,
        note: String = "",
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.scheduledAt = scheduledAt
        self.durationMinutes = max(1, durationMinutes)
        self.dependencyId = dependencyId
        self.linkedDishId = linkedDishId
        self.linkedProductId = linkedProductId
        self.status = status
        self.note = note
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    var endsAt: Date {
        scheduledAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var isFinished: Bool { status == .completed }
}

// MARK: - Leftovers

enum LeftoverStatus: String, Codable, CaseIterable, Hashable {
    case stored
    case used
    case discarded

    var displayName: String {
        switch self {
        case .stored: return "Stored"
        case .used: return "Used"
        case .discarded: return "Discarded"
        }
    }
}

struct Leftover: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: MeasurementUnit
    var sourceDishId: UUID?
    var zoneId: UUID?
    var storageNote: String
    /// Entered by the user. The app offers no guarantee about it.
    var useByDate: Date?
    var status: LeftoverStatus
    var createdAt: Date
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        sourceDishId: UUID? = nil,
        zoneId: UUID? = nil,
        storageNote: String = "",
        useByDate: Date? = nil,
        status: LeftoverStatus = .stored,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.sourceDishId = sourceDishId
        self.zoneId = zoneId
        self.storageNote = storageNote
        self.useByDate = useByDate
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
