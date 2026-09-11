//
//  InsightsService.swift
//  HarborPantry
//
//  Domain layer — turns recorded history into the Insights read model.
//
//  Every number here comes from entries the user created. Nothing is
//  estimated, and each metric keeps the ids of its source records so the UI
//  can always link back to them.
//

import Foundation

struct InsightsService {
    static let requiredWeeks = 3

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Counts distinct ISO weeks that contain at least one recorded action.
    func completedWeeks(from history: [ProductHistoryEntry], now: Date = Date()) -> Int {
        let currentWeek = weekKey(for: now)
        let keys = Set(
            history
                .map { weekKey(for: $0.createdAt) }
                // The week in progress is not "completed" yet.
                .filter { $0 != currentWeek }
        )
        return keys.count
    }

    func availability(from history: [ProductHistoryEntry], now: Date = Date()) -> InsightsAvailability {
        let weeks = completedWeeks(from: history, now: now)
        guard weeks >= Self.requiredWeeks else {
            return .locked(weeksCompleted: weeks, weeksRequired: Self.requiredWeeks)
        }
        return .available
    }

    func summary(
        history: [ProductHistoryEntry],
        mealEntries: [MealPlanEntry],
        dishes: [Dish],
        period: InsightsPeriod,
        now: Date = Date()
    ) -> InsightsSummary {
        let start = period.startDate(relativeTo: now, calendar: calendar)
        let scoped = history.filter { entry in
            guard let start = start else { return true }
            return entry.createdAt >= start
        }

        let discarded = scoped.filter { $0.kind == .discarded }
        let purchased = scoped.filter { $0.kind == .purchased }
        let used = scoped.filter { $0.kind == .used }

        let discardedByCategory = groupByCategory(discarded, idPrefix: "discarded")
        let purchasesByCategory = groupByCategory(purchased, idPrefix: "purchased")

        let scopedEntries = mealEntries.filter { entry in
            guard let start = start else { return true }
            return entry.date >= start
        }
        let dishNames = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0.trimmedName) })
        var dishCounts: [UUID: Int] = [:]
        for entry in scopedEntries {
            dishCounts[entry.dishId, default: 0] += 1
        }
        let popularDishes = dishCounts
            .compactMap { dishId, count -> InsightMetric? in
                guard let name = dishNames[dishId] else { return nil }
                return InsightMetric(
                    id: "dish-\(dishId.uuidString)",
                    label: name,
                    value: Double(count),
                    unitLabel: count == 1 ? "time" : "times",
                    sourceEntryIds: scopedEntries.filter { $0.dishId == dishId }.map(\.id)
                )
            }
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.label < rhs.label : lhs.value > rhs.value
            }

        // Purchases made within the same day count as one shopping trip.
        let tripDays = Set(purchased.map { calendar.startOfDay(for: $0.createdAt) })
        let averagePerTrip = tripDays.isEmpty ? 0 : Double(purchased.count) / Double(tripDays.count)

        return InsightsSummary(
            period: period,
            discardedByCategory: discardedByCategory,
            purchasesByCategory: purchasesByCategory,
            popularDishes: Array(popularDishes.prefix(6)),
            usedCount: used.count,
            discardedCount: discarded.count,
            purchasedCount: purchased.count,
            averageItemsPerShoppingTrip: averagePerTrip.roundedToTwoDecimals
        )
    }

    private func groupByCategory(
        _ entries: [ProductHistoryEntry],
        idPrefix: String
    ) -> [InsightMetric] {
        var buckets: [ProductCategory: [ProductHistoryEntry]] = [:]
        for entry in entries {
            buckets[entry.category ?? .other, default: []].append(entry)
        }
        return buckets
            .map { category, rows in
                InsightMetric(
                    id: "\(idPrefix)-\(category.rawValue)",
                    label: category.displayName,
                    value: Double(rows.count),
                    unitLabel: rows.count == 1 ? "item" : "items",
                    sourceEntryIds: rows.map(\.id)
                )
            }
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.label < rhs.label : lhs.value > rhs.value
            }
    }

    private func weekKey(for date: Date) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return "\(year)-W\(week)"
    }
}
