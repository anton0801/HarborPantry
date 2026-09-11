//
//  FreshnessService.swift
//  HarborPantry
//
//  Domain layer — groups products by the dates the *user* entered.
//
//  Nothing here is a safety judgement. The service only compares calendar
//  dates and never claims a product is spoiled, unsafe or inedible.
//

import Foundation

struct FreshnessService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Buckets a product by its user-entered use-by date relative to `now`.
    func bucket(for product: Product, now: Date = Date()) -> FreshnessBucket {
        guard let useBy = product.useByDate else { return .missingDate }
        return bucket(for: useBy, now: now)
    }

    func bucket(for date: Date, now: Date = Date()) -> FreshnessBucket {
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        switch days {
        case ..<0: return .review
        case 0: return .today
        case 1...3: return .nextThreeDays
        case 4...7: return .thisWeek
        default: return .later
        }
    }

    /// Days until the user's date. Negative when the date has already passed.
    func daysRemaining(for product: Product, now: Date = Date()) -> Int? {
        guard let useBy = product.useByDate else { return nil }
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: useBy)
        return calendar.dateComponents([.day], from: today, to: target).day
    }

    /// Products the user may want to look at first: dates already passed, then
    /// the nearest upcoming ones. Items without a date are never invented into
    /// this list — they are surfaced separately as "Missing Date".
    func useSoon(from products: [Product], now: Date = Date(), limit: Int? = nil) -> [Product] {
        let dated = products
            .filter { !$0.isArchived && $0.useByDate != nil }
            .filter { product in
                let bucket = bucket(for: product, now: now)
                return bucket == .review || bucket == .today || bucket == .nextThreeDays
            }
            .sorted { lhs, rhs in
                guard let l = lhs.useByDate, let r = rhs.useByDate else { return false }
                if l == r { return lhs.trimmedName < rhs.trimmedName }
                return l < r
            }
        guard let limit = limit else { return dated }
        return Array(dated.prefix(limit))
    }

    func group(products: [Product], now: Date = Date()) -> [FreshnessBucket: [Product]] {
        var result: [FreshnessBucket: [Product]] = [:]
        for product in products where !product.isArchived {
            let key = bucket(for: product, now: now)
            result[key, default: []].append(product)
        }
        for key in result.keys {
            result[key]?.sort { lhs, rhs in
                switch (lhs.useByDate, rhs.useByDate) {
                case let (l?, r?):
                    return l == r ? lhs.trimmedName < rhs.trimmedName : l < r
                case (nil, nil):
                    return lhs.trimmedName < rhs.trimmedName
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                }
            }
        }
        return result
    }
}
