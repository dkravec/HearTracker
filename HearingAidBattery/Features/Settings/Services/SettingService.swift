//
//  SettingService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation
import SwiftData

struct DeleteAllDataSummary {
    let spaces: Int
    let hearingAids: Int
    let batteryPacks: Int
    let issueLogs: Int
    let batteryLogs: Int
    let notifications: Int

    var total: Int {
        spaces + hearingAids + batteryPacks + issueLogs + batteryLogs + notifications
    }
}

struct DeleteCurrentSpaceResult {
    let summary: DeleteAllDataSummary
    let nextSpaceId: UUID?
}

@MainActor
struct SettingService {
    func deleteCurrentSpaceData(context: ModelContext) throws -> DeleteCurrentSpaceResult {
        let activeSpaceId = SpaceService.currentSpaceId(context: context)
        let currentSpace = try context.fetch(
            FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.id == activeSpaceId })
        ).first

        let hearingAids = try context.fetch(
            FetchDescriptor<HearingAid>(predicate: #Predicate<HearingAid> { $0.spaceId == activeSpaceId })
        )
        for item in hearingAids { context.delete(item) }

        let packs = try context.fetch(
            FetchDescriptor<BatteryPack>(predicate: #Predicate<BatteryPack> { $0.spaceId == activeSpaceId })
        )
        for item in packs { context.delete(item) }

        let issues = try context.fetch(
            FetchDescriptor<IssueLog>(predicate: #Predicate<IssueLog> { $0.spaceId == activeSpaceId })
        )
        for item in issues { context.delete(item) }

        let logs = try context.fetch(
            FetchDescriptor<BatteryLog>(predicate: #Predicate<BatteryLog> { $0.spaceId == activeSpaceId })
        )
        for item in logs { context.delete(item) }

        if let currentSpace {
            context.delete(currentSpace)
        }

        try context.save()
        let remainingSpaces = try context.fetch(
            FetchDescriptor<Space>(sortBy: [SortDescriptor(\Space.createdAt, order: .forward)])
        )

        return DeleteCurrentSpaceResult(
            summary: DeleteAllDataSummary(
                spaces: currentSpace == nil ? 0 : 1,
                hearingAids: hearingAids.count,
                batteryPacks: packs.count,
                issueLogs: issues.count,
                batteryLogs: logs.count,
                notifications: 0
            ),
            nextSpaceId: remainingSpaces.first?.id
        )
    }

    func deleteAllData(context: ModelContext) throws -> DeleteAllDataSummary {
        let spaces = try context.fetch(FetchDescriptor<Space>())
        for item in spaces { context.delete(item) }

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
            spaces: spaces.count,
            hearingAids: hearingAids.count,
            batteryPacks: packs.count,
            issueLogs: issues.count,
            batteryLogs: logs.count,
            notifications: notificationSettings.count
        )
    }

    func deleteAllBatteryLogs(context: ModelContext) throws -> Int {
        let activeSpaceId = SpaceService.currentSpaceId(context: context)
        let logs = try context.fetch(
            FetchDescriptor<BatteryLog>(predicate: #Predicate<BatteryLog> { $0.spaceId == activeSpaceId })
        )
        for log in logs {
            context.delete(log)
        }
        try context.save()
        return logs.count
    }

    func deleteBatteryLogs(for hearingAidId: UUID?, context: ModelContext) throws -> Int {
        let descriptor: FetchDescriptor<BatteryLog>
        let activeSpaceId = SpaceService.currentSpaceId(context: context)
        if let hearingAidId {
            descriptor = FetchDescriptor<BatteryLog>(
                predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId && $0.spaceId == activeSpaceId }
            )
        } else {
            descriptor = FetchDescriptor<BatteryLog>(
                predicate: #Predicate<BatteryLog> { $0.spaceId == activeSpaceId }
            )
        }

        let logs = try context.fetch(descriptor)
        for log in logs {
            context.delete(log)
        }
        try context.save()
        return logs.count
    }

    func transferBatteryLogs(from sourceHearingAidId: UUID, to targetHearingAidId: UUID, context: ModelContext) throws -> Int {
        guard sourceHearingAidId != targetHearingAidId else { return 0 }

        let activeSpaceId = SpaceService.currentSpaceId(context: context)
        guard let targetHearingAid = try context.fetch(
            FetchDescriptor<HearingAid>(
                predicate: #Predicate<HearingAid> { $0.id == targetHearingAidId && $0.spaceId == activeSpaceId }
            )
        ).first else {
            return 0
        }

        let logs = try context.fetch(
            FetchDescriptor<BatteryLog>(
                predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == sourceHearingAidId && $0.spaceId == activeSpaceId }
            )
        )
        guard logs.isEmpty == false else { return 0 }

        let movedLogIds = Set(logs.map(\.id))
        for log in logs {
            log.hearingAid = targetHearingAid
        }

        let sourceIssues = try context.fetch(
            FetchDescriptor<IssueLog>(
                predicate: #Predicate<IssueLog> { $0.hearingAid?.id == sourceHearingAidId && $0.spaceId == activeSpaceId }
            )
        )
        for issue in sourceIssues where issue.linkedBatteryLogId.map({ movedLogIds.contains($0) }) == true {
            issue.hearingAid = targetHearingAid
        }

        try context.save()
        return logs.count
    }
}
