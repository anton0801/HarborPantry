//
//  PantryProfile.swift
//  HarborPantry
//
//  Domain layer — the household setup that drives portions, units and filters.
//

import Foundation

struct PantryProfile: Codable, Hashable, Identifiable {
    static let minimumPeople = 1
    static let maximumPeople = 50

    let id: UUID
    var householdName: String
    var peopleCount: Int
    var defaultUnit: MeasurementUnit
    var currencyCode: String
    /// Free-text notes the user keeps for themselves. The app treats this as a
    /// label only: it never derives medical or safety conclusions from it.
    var dietaryNotes: String
    var weekStart: Weekday
    var isConfigured: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        householdName: String = "",
        peopleCount: Int = 2,
        defaultUnit: MeasurementUnit = .piece,
        currencyCode: String = "USD",
        dietaryNotes: String = "",
        weekStart: Weekday = .monday,
        isConfigured: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.householdName = householdName
        self.peopleCount = peopleCount.clamped(to: Self.minimumPeople...Self.maximumPeople)
        self.defaultUnit = defaultUnit
        self.currencyCode = currencyCode
        self.dietaryNotes = dietaryNotes
        self.weekStart = weekStart
        self.isConfigured = isConfigured
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var currency: CurrencyOption { CurrencyOption.option(for: currencyCode) }

    var displayName: String {
        let trimmed = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "My Pantry" : trimmed
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
