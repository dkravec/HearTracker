//
//  SettingService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation
import SwiftData

struct DeleteAllDataSummary {
    let hearingAids: Int
    let batteryPacks: Int
    let issueLogs: Int
    let batteryLogs: Int
    let notifications: Int

    var total: Int {
        hearingAids + batteryPacks + issueLogs + batteryLogs + notifications
    }
}

@MainActor
struct SettingService {
    func deleteAllData(context: ModelContext) throws -> DeleteAllDataSummary {
        let hearingAids = try context.fetch(FetchDescriptor<HearingAid>())
        for item in hearingAids { context.delete(item) }

        let packs = try context.fetch(FetchDescriptor<BatteryPack>())
        for item in packs { context.delete(item) }

        let issues = try context.fetch(FetchDescriptor<IssueLog>())
        for item in issues { context.delete(item) }

        let logs = try context.fetch(FetchDescriptor<BatteryLog>())
        for item in logs { context.delete(item) }

        let notificationSettings = try context.fetch(FetchDescriptor<NotificationModel>())
        for item in notificationSettings { context.delete(item) }

        try context.save()
        return DeleteAllDataSummary(
            hearingAids: hearingAids.count,
            batteryPacks: packs.count,
            issueLogs: issues.count,
            batteryLogs: logs.count,
            notifications: notificationSettings.count
        )
    }

    func deleteAllBatteryLogs(context: ModelContext) throws -> Int {
        let logs = try context.fetch(FetchDescriptor<BatteryLog>())
        for log in logs {
            context.delete(log)
        }
        try context.save()
        return logs.count
    }

    func deleteBatteryLogs(for hearingAidId: UUID?, context: ModelContext) throws -> Int {
        let descriptor: FetchDescriptor<BatteryLog>
        if let hearingAidId {
            descriptor = FetchDescriptor<BatteryLog>(
                predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId }
            )
        } else {
            descriptor = FetchDescriptor<BatteryLog>()
        }

        let logs = try context.fetch(descriptor)
        for log in logs {
            context.delete(log)
        }
        try context.save()
        return logs.count
    }
}
