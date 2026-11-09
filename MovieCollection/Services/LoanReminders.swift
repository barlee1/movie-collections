//
//  LoanReminders.swift
//  MovieCollection
//
//  Purpose: Local notifications for loaned discs that have a due-back date,
//  e.g. "Ask Sam for Inception back" at 9 AM that day. After every shelf
//  change the pending reminders are replaced with the current set, so a
//  return, a new date, a deleted title, or deleting everything all stay
//  correct without tracking each one. Permission is asked the first time a
//  due date is set, never at launch.
//  Used in: AppViewModel (reloadShelf and move), MovieCollectionApp.
//

import Foundation
import UserNotifications

/// One reminder to schedule.
nonisolated struct LoanReminder: Sendable, Equatable {
    let title: String
    let body: String
    let fireDate: Date

    /// The hour on the due-back day the reminder goes off.
    static let hour = 9

    /// Reminders for every loaned disc with a due date whose reminder is still ahead.
    /// On the main actor, like the shelf it reads.
    @MainActor
    static func reminders(for titles: [OwnedTitle], now: Date = .now, calendar: Calendar = .current) -> [LoanReminder] {
        titles.compactMap { title in
            guard title.isLoanedOut, let due = title.loanDueOn,
                let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: due),
                fireDate > now
            else { return nil }
            let heading = title.loanedTo.map { "Ask \($0) for \(title.title) back" } ?? "\(title.title) is due back"
            let body = title.loanedOn.map { "Loaned since \($0.displayText). It's due back today." } ?? "It's due back today."
            return LoanReminder(title: heading, body: body, fireDate: fireDate)
        }
    }
}

/// Schedules loan reminders. The app uses `SystemLoanReminders`; previews and tests use `NoLoanReminders`.
nonisolated protocol LoanReminderScheduling: Sendable {
    /// Replaces every pending loan reminder with these.
    func sync(_ reminders: [LoanReminder]) async
    /// Asks to show notifications, if the user hasn't been asked yet.
    func requestPermissionIfNeeded() async
}

/// Does nothing. For previews, tests, and UI tests.
nonisolated struct NoLoanReminders: LoanReminderScheduling {
    func sync(_ reminders: [LoanReminder]) async {}
    func requestPermissionIfNeeded() async {}
}

/// Real local notifications through UNUserNotificationCenter.
nonisolated struct SystemLoanReminders: LoanReminderScheduling {
    private static let idPrefix = "loanDue-"

    func sync(_ reminders: [LoanReminder]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) })

        // Nothing to do until the user allows notifications (asked when they set a due date).
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        for (index, reminder) in reminders.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let request = UNNotificationRequest(
                identifier: "\(Self.idPrefix)\(index)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }
}
