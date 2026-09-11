//
//  CoreValueTypes.swift
//  HarborPantry
//
//  Domain layer — shared value types used across entities.
//

import Foundation

// MARK: - Measurement unit

/// Units the user can assign to products, ingredients and shopping rows.
///
/// Units are grouped into *dimensions*. Quantities from different dimensions are
/// never merged automatically — the user has to resolve that themselves.
enum MeasurementUnit: String, Codable, CaseIterable, Hashable, Identifiable {
    case piece
    case pack
    case gram
    case kilogram
    case milliliter
    case liter
    case tablespoon
    case teaspoon
    case cup
    case can
    case bottle
    case bunch

    var id: String { rawValue }

    enum Dimension: String, Codable, Hashable {
        case count
        case mass
        case volume
    }

    var dimension: Dimension {
        switch self {
        case .piece, .pack, .can, .bottle, .bunch:
            return .count
        case .gram, .kilogram:
            return .mass
        case .milliliter, .liter, .tablespoon, .teaspoon, .cup:
            return .volume
        }
    }

    var shortLabel: String {
        switch self {
        case .piece: return "pc"
        case .pack: return "pack"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .milliliter: return "ml"
        case .liter: return "l"
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
        case .cup: return "cup"
        case .can: return "can"
        case .bottle: return "bottle"
        case .bunch: return "bunch"
        }
    }

    var displayName: String {
        switch self {
        case .piece: return "Pieces"
        case .pack: return "Packs"
        case .gram: return "Grams"
        case .kilogram: return "Kilograms"
        case .milliliter: return "Milliliters"
        case .liter: return "Liters"
        case .tablespoon: return "Tablespoons"
        case .teaspoon: return "Teaspoons"
        case .cup: return "Cups"
        case .can: return "Cans"
        case .bottle: return "Bottles"
        case .bunch: return "Bunches"
        }
    }

    /// Factor relative to the dimension's base unit (piece / gram / milliliter).
    var baseFactor: Double {
        switch self {
        case .piece, .pack, .can, .bottle, .bunch: return 1
        case .gram: return 1
        case .kilogram: return 1000
        case .milliliter: return 1
        case .liter: return 1000
        case .teaspoon: return 5
        case .tablespoon: return 15
        case .cup: return 240
        }
    }

    /// Units that share this unit's dimension, so they can be converted safely.
    var compatibleUnits: [MeasurementUnit] {
        MeasurementUnit.allCases.filter { $0.dimension == dimension }
    }

    /// Converts `value` from the receiver into `target`.
    /// Returns `nil` when the two units belong to different dimensions —
    /// the app never guesses across dimensions.
    func convert(_ value: Double, to target: MeasurementUnit) -> Double? {
        guard dimension == target.dimension else { return nil }
        // Count-like units are only interchangeable with themselves; a "pack"
        // is not a known number of "pieces" unless the user says so.
        if dimension == .count && self != target { return nil }
        return value * baseFactor / target.baseFactor
    }
}

// MARK: - Product category

enum ProductCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case fish
    case seafood
    case meat
    case dairy
    case vegetables
    case fruit
    case grains
    case bakery
    case frozen
    case pantryStaples
    case drinks
    case sauces
    case herbs
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fish: return "Fish"
        case .seafood: return "Seafood"
        case .meat: return "Meat"
        case .dairy: return "Dairy"
        case .vegetables: return "Vegetables"
        case .fruit: return "Fruit"
        case .grains: return "Grains"
        case .bakery: return "Bakery"
        case .frozen: return "Frozen"
        case .pantryStaples: return "Pantry Staples"
        case .drinks: return "Drinks"
        case .sauces: return "Sauces"
        case .herbs: return "Herbs"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .fish: return "fish"
        case .seafood: return "water.waves"
        case .meat: return "flame"
        case .dairy: return "drop"
        case .vegetables: return "carrot"
        case .fruit: return "applelogo"
        case .grains: return "leaf"
        case .bakery: return "birthday.cake"
        case .frozen: return "snowflake"
        case .pantryStaples: return "shippingbox"
        case .drinks: return "cup.and.saucer"
        case .sauces: return "takeoutbag.and.cup.and.straw"
        case .herbs: return "leaf.circle"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Weekday

enum Weekday: Int, Codable, CaseIterable, Hashable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var shortName: String { String(displayName.prefix(3)) }
}

// MARK: - Currency

/// A small, offline list of currencies. The app never fetches rates and never
/// converts between currencies — the code is a label for the user's own prices.
struct CurrencyOption: Codable, Hashable, Identifiable {
    let code: String
    let symbol: String
    let name: String

    var id: String { code }

    static let all: [CurrencyOption] = [
        CurrencyOption(code: "USD", symbol: "$", name: "US Dollar"),
        CurrencyOption(code: "EUR", symbol: "€", name: "Euro"),
        CurrencyOption(code: "GBP", symbol: "£", name: "British Pound"),
        CurrencyOption(code: "PLN", symbol: "zł", name: "Polish Złoty"),
        CurrencyOption(code: "CZK", symbol: "Kč", name: "Czech Koruna"),
        CurrencyOption(code: "SEK", symbol: "kr", name: "Swedish Krona"),
        CurrencyOption(code: "NOK", symbol: "kr", name: "Norwegian Krone"),
        CurrencyOption(code: "CAD", symbol: "$", name: "Canadian Dollar"),
        CurrencyOption(code: "AUD", symbol: "$", name: "Australian Dollar"),
        CurrencyOption(code: "JPY", symbol: "¥", name: "Japanese Yen")
    ]

    static let fallback = CurrencyOption(code: "USD", symbol: "$", name: "US Dollar")

    static func option(for code: String) -> CurrencyOption {
        all.first { $0.code == code } ?? fallback
    }
}
