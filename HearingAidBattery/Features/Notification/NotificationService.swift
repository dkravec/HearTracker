//
//  NotificationService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService {
    private let statsService: BatteryStatsService
    private let notificationCenter: UNUserNotificationCenter
    private let windowSize: Int

    init(
        statsService: BatteryStatsService? = nil,
        notificationCenter: UNUserNotificationCenter = .current(),
        windowSize: Int = 10
    ) {
        self.statsService = statsService ?? BatteryStatsService()
        self.notificationCenter = notificationCenter
        self.windowSize = windowSize
    }

    func loadOrCreateSettings(context: ModelContext) -> NotificationModel {
        let descriptor = FetchDescriptor<NotificationModel>(
            sortBy: [SortDescriptor(\NotificationModel.createdAt, order: .forward)]
        )
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            return first
        }

        let created = NotificationModel()
        context.insert(created)
        try? context.save()
        return created
    }

    func saveSettings(
        isEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        context: ModelContext
    ) {
        let settings = loadOrCreateSettings(context: context)
        settings.isEnabled = isEnabled
        settings.morningHour = min(max(morningHour, 0), 23)
        settings.morningMinute = min(max(morningMinute, 0), 59)
        try? context.save()
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func rescheduleAll(context: ModelContext) async {
        let descriptor = FetchDescriptor<HearingAid>(
            predicate: #Predicate<HearingAid> { $0.retired == false }
        )
        let aids = (try? context.fetch(descriptor)) ?? []
        for aid in aids {
            await rescheduleNotifications(for: aid.id, context: context)
        }
    }

    func rescheduleNotifications(for hearingAidId: UUID, context: ModelContext) async {
        cancelPendingRequests(for: hearingAidId)

        let settings = loadOrCreateSettings(context: context)
        guard settings.isEnabled else { return }
        guard await requestPermissionIfNeeded() else { return }

        let now = Date()
        let snapshot = statsService.statsSnapshot(
            for: hearingAidId,
            windowSize: windowSize,
            context: context,
            referenceDate: now
        )
        guard let predictedDeath = snapshot.predictedDeath else { return }
        guard let hearingAid = (try? context.fetch(
            FetchDescriptor<HearingAid>(predicate: #Predicate<HearingAid> { $0.id == hearingAidId })
        ))?.first else {
            return
        }

        let oneHourWarningDate = predictedDeath.addingTimeInterval(-3600)
        if oneHourWarningDate > now {
            let content = UNMutableNotificationContent()
            content.title = "\(hearingAid.name) battery warning"
            content.body = "Estimated to die in about 1 hour."
            content.sound = .default
            await schedule(
                identifier: oneHourRequestId(for: hearingAidId),
                content: content,
                triggerDate: oneHourWarningDate
            )
        }

        let withinNextDay = predictedDeath <= now.addingTimeInterval(24 * 3600)
        if withinNextDay,
           let morningDate = nextMorningDate(hour: settings.morningHour, minute: settings.morningMinute, now: now),
           morningDate > now,
           morningDate <= predictedDeath {
            let content = UNMutableNotificationContent()
            content.title = "Morning Heads-up"
            content.body = "\(hearingAid.name) Hearing Aid Battery may die today. Bring your next pack."
            content.sound = .default
            await schedule(
                identifier: morningRequestId(for: hearingAidId),
                content: content,
                triggerDate: morningDate
            )
        }
    }

    private func cancelPendingRequests(for hearingAidId: UUID) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [morningRequestId(for: hearingAidId), oneHourRequestId(for: hearingAidId)]
        )
    }

    private func schedule(identifier: String, content: UNMutableNotificationContent, triggerDate: Date) async {
        let triggerDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        _ = await withCheckedContinuation { continuation in
            notificationCenter.add(request) { _ in
                continuation.resume()
            }
        }
    }

    private func morningRequestId(for hearingAidId: UUID) -> String {
        "notif.morning.\(hearingAidId.uuidString)"
    }

    private func oneHourRequestId(for hearingAidId: UUID) -> String {
        "notif.onehour.\(hearingAidId.uuidString)"
    }

    private func nextMorningDate(hour: Int, minute: Int, now: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let today = Calendar.current.date(from: components) else { return nil }
        if today > now {
            return today
        }
        return Calendar.current.date(byAdding: .day, value: 1, to: today)
    }
}
