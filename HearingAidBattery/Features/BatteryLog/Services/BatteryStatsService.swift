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
        snapshotAndDurations(
            for: hearingAidId,
            windowSize: windowSize,
            context: context
        ).durations
    }

    func averageDuration(for hearingAidId: UUID, windowSize: Int, context: ModelContext) -> TimeInterval? {
        snapshotAndDurations(
            for: hearingAidId,
            windowSize: windowSize,
            context: context
        ).snapshot.avgDuration
    }

    func predictedDeath(for hearingAidId: UUID, windowSize: Int, context: ModelContext) -> Date? {
        snapshotAndDurations(
            for: hearingAidId,
            windowSize: windowSize,
            context: context
        ).snapshot.predictedDeath
    }

    func currentBatteryAge(
        for hearingAidId: UUID,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> TimeInterval? {
        snapshotAndDurations(
            for: hearingAidId,
            windowSize: 0,
            context: context,
            referenceDate: referenceDate
        ).snapshot.currentAge
    }

    func statsSnapshot(
        for hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> BatteryStatsSnapshot {
        snapshotAndDurations(
            for: hearingAidId,
            windowSize: windowSize,
            context: context,
            referenceDate: referenceDate
        ).snapshot
    }

    func statsSnapshot(
        from sortedLogs: [BatteryLog],
        windowSize: Int,
        referenceDate: Date = Date()
    ) -> BatteryStatsSnapshot {
        let sampleDurations = durations(from: sortedLogs, windowSize: windowSize)
        return statsSnapshot(
            from: sortedLogs,
            sampleDurations: sampleDurations,
            referenceDate: referenceDate
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

    private func snapshotAndDurations(
        for hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> (snapshot: BatteryStatsSnapshot, durations: [TimeInterval]) {
        let logs = sortedLogs(for: hearingAidId, context: context)
        let sampleDurations = durations(from: logs, windowSize: windowSize)
        let snapshot = statsSnapshot(
            from: logs,
            sampleDurations: sampleDurations,
            referenceDate: referenceDate
        )
        return (snapshot, sampleDurations)
    }

    private func statsSnapshot(
        from sortedLogs: [BatteryLog],
        sampleDurations: [TimeInterval],
        referenceDate: Date
    ) -> BatteryStatsSnapshot {
        guard let currentLog = sortedLogs.first else {
            return .empty
        }

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
}
