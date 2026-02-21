//
//  BatteryLogService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftData
import Foundation

@MainActor
final class BatteryLogService {
    func quickLog(for aid: HearingAid, note: String? = nil, context: ModelContext) throws {
        // Find current log (if any)
        let logs = aid.logs ?? []
        let current = logs
            .filter { $0.isCurrent }
            .sorted { $0.timestamp > $1.timestamp }
            .first

        // Create new log (becomes current)
        let newLog = BatteryLog(hearingAid: aid, timestamp: Date(), note: note, isCurrent: true)
        context.insert(newLog)

        // If there was a current, retire it + link it to the new log
        if let current {
            current.isCurrent = false
            current.nextLogId = newLog.id
        }

        // Optional: if somehow multiple “current” exist, normalize
        for extra in logs where extra.id != newLog.id && extra.isCurrent {
            extra.isCurrent = false
        }

        try context.save()
    }
}

func durationString(for log: BatteryLog, in logs: [BatteryLog]) -> String? {
    guard let nextId = log.nextLogId,
          let next = logs.first(where: { $0.id == nextId }) else { return nil }

    let seconds = next.timestamp.timeIntervalSince(log.timestamp)
    let days = seconds / 86400.0
    return String(format: "%.1f days", days)
}
