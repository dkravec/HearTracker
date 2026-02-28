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
    let currentAge: TimeInterval?
    let avgDuration: TimeInterval?
    let predictedDeath: Date?
    let sampleCount: Int

    static let empty = BatteryStatsSnapshot(
        currentLogId: nil,
        currentAge: nil,
        avgDuration: nil,
        predictedDeath: nil,
        sampleCount: 0
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
    func sortedLogs(for hearingAidId: UUID, context: ModelContext) -> [BatteryLog] {
        let descriptor = FetchDescriptor<BatteryLog>(
            predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId },
            sortBy: [SortDescriptor(\BatteryLog.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func durations(for hearingAidId: UUID, windowSize: Int, context: ModelContext) -> [TimeInterval] {
        let logs = sortedLogs(for: hearingAidId, context: context)
        return durations(from: logs, windowSize: windowSize)
    }

    func averageDuration(for hearingAidId: UUID, windowSize: Int, context: ModelContext) -> TimeInterval? {
        let sampleDurations = durations(for: hearingAidId, windowSize: windowSize, context: context)
        guard sampleDurations.isEmpty == false else { return nil }
        return sampleDurations.reduce(0, +) / Double(sampleDurations.count)
    }

    func predictedDeath(for hearingAidId: UUID, windowSize: Int, context: ModelContext) -> Date? {
        let logs = sortedLogs(for: hearingAidId, context: context)
        guard let currentLog = logs.first else { return nil }
        guard let average = averageDuration(for: hearingAidId, windowSize: windowSize, context: context) else { return nil }
        return currentLog.timestamp.addingTimeInterval(average)
    }

    func currentBatteryAge(
        for hearingAidId: UUID,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> TimeInterval? {
        let logs = sortedLogs(for: hearingAidId, context: context)
        guard let currentLog = logs.first else { return nil }
        return max(0, referenceDate.timeIntervalSince(currentLog.timestamp))
    }

    func statsSnapshot(
        for hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> BatteryStatsSnapshot {
        let logs = sortedLogs(for: hearingAidId, context: context)
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

        let sampleDurations = durations(from: sortedLogs, windowSize: windowSize)
        let avgDuration = sampleDurations.isEmpty ? nil : sampleDurations.reduce(0, +) / Double(sampleDurations.count)
        let currentAge = max(0, referenceDate.timeIntervalSince(currentLog.timestamp))
        let predictedDeath = avgDuration.map { currentLog.timestamp.addingTimeInterval($0) }

        return BatteryStatsSnapshot(
            currentLogId: currentLog.id,
            currentAge: currentAge,
            avgDuration: avgDuration,
            predictedDeath: predictedDeath,
            sampleCount: sampleDurations.count
        )
    }

    private func durations(from sortedLogs: [BatteryLog], windowSize: Int) -> [TimeInterval] {
        let completedDurations = sortedLogs.enumerated().compactMap { index, log -> TimeInterval? in
            guard index > 0 else { return nil }
            let newerLog = sortedLogs[index - 1]
            guard log.excludeFromStats == false else { return nil }
            guard newerLog.excludePreviousGapFromStats == false else { return nil }
            let duration = newerLog.timestamp.timeIntervalSince(log.timestamp)
            return duration > 0 ? duration : nil
        }

        if windowSize > 0 {
            return Array(completedDurations.prefix(windowSize))
        }
        return completedDurations
    }
}
