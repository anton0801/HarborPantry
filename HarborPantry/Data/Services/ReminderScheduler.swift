//
//  ReminderScheduler.swift
//  HarborPantry
//
//  Data layer — local notifications. Declining permission never blocks any
//  feature; the app simply skips scheduling.
//

import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationGranted() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func schedule(_ reminder: PantryReminder) async throws {
        guard await authorizationGranted() else {
            throw DomainError.validation(
                "Reminders are off. You can turn them on in Settings whenever you like."
            )
        }
        guard reminder.fireDate > Date() else {
            throw DomainError.validation("Choose a time in the future for this reminder.")
        }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            throw DomainError.persistence("Could not schedule that reminder.")
        }
    }

    func cancel(id: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }
}
