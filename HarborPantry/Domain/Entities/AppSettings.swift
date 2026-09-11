//
//  AppSettings.swift
//  HarborPantry
//
//  Domain layer — device-local preferences and app lifecycle flags.
//

import Foundation

struct AppSettings: Codable, Hashable {
    var hasCompletedOnboarding: Bool
    /// The user's own choice from the last onboarding slide. Declining never
    /// blocks any part of the app.
    var remindersEnabled: Bool
    var homeFilter: HomeFilter
    var lastOpenedAt: Date?
    /// Weeks the user has closed out; Insights stays locked until three.
    var completedWeekKeys: [String]

    init(
        hasCompletedOnboarding: Bool = false,
        remindersEnabled: Bool = false,
        homeFilter: HomeFilter = .today,
        lastOpenedAt: Date? = nil,
        completedWeekKeys: [String] = []
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.remindersEnabled = remindersEnabled
        self.homeFilter = homeFilter
        self.lastOpenedAt = lastOpenedAt
        self.completedWeekKeys = completedWeekKeys
    }
}

enum HomeFilter: String, Codable, CaseIterable, Hashable, Identifiable {
    case today
    case thisWeek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        }
    }
}

// MARK: - Reminders

struct PantryReminder: Codable, Hashable, Identifiable {
    enum Subject: Codable, Hashable {
        case product(UUID)
        case prepTask(UUID)
        case leftover(UUID)
    }

    let id: UUID
    var title: String
    var body: String
    var fireDate: Date
    var subject: Subject
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        fireDate: Date,
        subject: Subject,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.subject = subject
        self.createdAt = createdAt
    }
}
