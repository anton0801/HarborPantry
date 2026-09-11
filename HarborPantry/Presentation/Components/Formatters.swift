//
//  Formatters.swift
//  HarborPantry
//
//  Presentation layer — shared display formatting.
//

import Foundation

enum HarborFormat {
    static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let weekdayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formats a quantity with its unit, e.g. "1.5 kg".
    static func quantity(_ value: Double, _ unit: MeasurementUnit) -> String {
        "\(value.quantityText) \(unit.shortLabel)"
    }

    /// Formats a price using the household's chosen currency symbol.
    static func price(_ value: Double, currency: CurrencyOption) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(currency.symbol)\(number)"
    }

    /// Human phrasing for how far away the user's own date is.
    static func relativeDays(_ days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "1 day ago"
        case ..<(-1): return "\(-days) days ago"
        default: return "In \(days) days"
        }
    }

    static func duration(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}
