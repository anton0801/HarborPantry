//
//  DomainError.swift
//  HarborPantry
//
//  Domain layer — validation and persistence failures surfaced to the user.
//

import Foundation

enum DomainError: LocalizedError, Equatable {
    case validation(String)
    case notFound(String)
    case conflict(String)
    case persistence(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case let .validation(message): return message
        case let .notFound(message): return message
        case let .conflict(message): return message
        case let .persistence(message): return message
        case let .importFailed(message): return message
        }
    }

    var title: String {
        switch self {
        case .validation: return "Check the form"
        case .notFound: return "Not found"
        case .conflict: return "Conflict"
        case .persistence: return "Could not save"
        case .importFailed: return "Import failed"
        }
    }
}
