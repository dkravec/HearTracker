//
//  SettingService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation
import SwiftData

@MainActor
struct SettingService {
    func deleteAllData(context: ModelContext) throws -> Int {
        var deletedCount = 0

        let hearingAids = try context.fetch(FetchDescriptor<HearingAid>())
        for item in hearingAids {
            context.delete(item)
            deletedCount += 1
        }

        let packs = try context.fetch(FetchDescriptor<BatteryPack>())
        for item in packs {
            context.delete(item)
            deletedCount += 1
        }

        let issues = try context.fetch(FetchDescriptor<IssueLog>())
        for item in issues {
            context.delete(item)
            deletedCount += 1
        }

        let logs = try context.fetch(FetchDescriptor<BatteryLog>())
        for item in logs {
            context.delete(item)
            deletedCount += 1
        }

        try context.save()
        return deletedCount
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
