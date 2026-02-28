//
//  BatteryStatsService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

struct BatteryStatsSnapshot {
    let currentLogId: UUID?
    let currentInsertedAt: Date?
    let currentBatteryAge: TimeInterval?
    let avgDuration: TimeInterval?
    let predictedDeath: Date?
    let sampleCount: Int
    let lastCompletedDuration: TimeInterval?

    static let empty = BatteryStatsSnapshot(
        currentLogId: nil,
        currentInsertedAt: nil,
        currentBatteryAge: nil,
        avgDuration: nil,
        predictedDeath: nil,
        sampleCount: 0,
        lastCompletedDuration: nil
    )
}

@MainActor
protocol BatteryStatsProviding {
    func statsSnapshot(
        for hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date
    ) -> BatteryStatsSnapshot
}

@MainActor
final class BatteryStatsService: BatteryStatsProviding {
    func statsSnapshot(
        for hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> BatteryStatsSnapshot {
        let descriptor = FetchDescriptor<BatteryLog>(
            predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId },
            sortBy: [SortDescriptor(\BatteryLog.timestamp, order: .reverse)]
        )

        let logs = (try? context.fetch(descriptor)) ?? []
        return statsSnapshot(from: logs, windowSize: windowSize, referenceDate: referenceDate)
    }

    func statsSnapshot(
        from sortedLogs: [BatteryLog],
        windowSize: Int,
        referenceDate: Date = Date()
    ) -> BatteryStatsSnapshot {
        guard let currentLog = sortedLogs.first else {
            return .empty
        }

        let completedDurations = sortedLogs.enumerated().compactMap { index, log -> TimeInterval? in
            guard index > 0 else { return nil }
            let newerLog = sortedLogs[index - 1]
            guard log.excludeFromStats == false else { return nil }
            guard newerLog.excludePreviousGapFromStats == false else { return nil }
            let duration = newerLog.timestamp.timeIntervalSince(log.timestamp)
            return duration > 0 ? duration : nil
        }

        let sampleDurations: [TimeInterval]
        if windowSize > 0 {
            sampleDurations = Array(completedDurations.prefix(windowSize))
        } else {
            sampleDurations = completedDurations
        }

        let avgDuration: TimeInterval?
        if sampleDurations.isEmpty {
            avgDuration = nil
        } else {
            avgDuration = sampleDurations.reduce(0, +) / Double(sampleDurations.count)
        }

        let currentBatteryAge = max(0, referenceDate.timeIntervalSince(currentLog.timestamp))
        let predictedDeath = avgDuration.map { currentLog.timestamp.addingTimeInterval($0) }

        return BatteryStatsSnapshot(
            currentLogId: currentLog.id,
            currentInsertedAt: currentLog.timestamp,
            currentBatteryAge: currentBatteryAge,
            avgDuration: avgDuration,
            predictedDeath: predictedDeath,
            sampleCount: sampleDurations.count,
            lastCompletedDuration: completedDurations.first
        )
    }
}
