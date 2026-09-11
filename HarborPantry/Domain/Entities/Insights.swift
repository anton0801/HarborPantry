//
//  Insights.swift
//  HarborPantry
//
//  Domain layer — read models produced from the user's own history.
//

import Foundation

/// Insights unlock only after three completed weeks of real data.
enum InsightsAvailability: Hashable {
    case locked(weeksCompleted: Int, weeksRequired: Int)
    case available

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

enum InsightsPeriod: String, CaseIterable, Identifiable, Hashable {
    case lastThreeWeeks
    case lastMonth
    case allTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lastThreeWeeks: return "Last 3 Weeks"
        case .lastMonth: return "Last Month"
        case .allTime: return "All Time"
        }
    }

    /// Start of the window, or `nil` for all time.
    func startDate(relativeTo now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .lastThreeWeeks:
            return calendar.date(byAdding: .day, value: -21, to: calendar.startOfDay(for: now))
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: now))
        case .allTime:
            return nil
        }
    }
}

/// One row of a breakdown, always traceable back to its source records.
struct InsightMetric: Hashable, Identifiable {
    let id: String
    let label: String
    let value: Double
    let unitLabel: String
    let sourceEntryIds: [UUID]

    init(
        id: String,
        label: String,
        value: Double,
        unitLabel: String = "",
        sourceEntryIds: [UUID] = []
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.unitLabel = unitLabel
        self.sourceEntryIds = sourceEntryIds
    }
}

struct InsightsSummary: Hashable {
    let period: InsightsPeriod
    let discardedByCategory: [InsightMetric]
    let purchasesByCategory: [InsightMetric]
    let popularDishes: [InsightMetric]
    let usedCount: Int
    let discardedCount: Int
    let purchasedCount: Int
    let averageItemsPerShoppingTrip: Double

    /// Share of resolved products that were actually used, 0...1.
    var stockUsageRate: Double {
        let total = usedCount + discardedCount
        guard total > 0 else { return 0 }
        return Double(usedCount) / Double(total)
    }

    static let empty = InsightsSummary(
        period: .lastThreeWeeks,
        discardedByCategory: [],
        purchasesByCategory: [],
        popularDishes: [],
        usedCount: 0,
        discardedCount: 0,
        purchasedCount: 0,
        averageItemsPerShoppingTrip: 0
    )
}
