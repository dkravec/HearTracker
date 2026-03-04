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

struct DurationDataPoint: Identifiable {
    let id: UUID
    let index: Int
    let duration: TimeInterval
    let timestamp: Date
}

struct DetailedBatteryStats {
    let snapshot: BatteryStatsSnapshot
    let allTimeAvgDuration: TimeInterval?
    let recentAvgDuration: TimeInterval?
    let minDuration: TimeInterval?
    let maxDuration: TimeInterval?
    let totalBatteriesUsed: Int
    let durationHistory: [DurationDataPoint]
    let trend: Trend

    enum Trend: String {
        case improving = "Improving"
        case declining = "Declining"
        case stable = "Stable"
        case unknown = "Not enough data"
    }

    static let empty = DetailedBatteryStats(
        snapshot: .empty,
        allTimeAvgDuration: nil,
        recentAvgDuration: nil,
        minDuration: nil,
        maxDuration: nil,
        totalBatteriesUsed: 0,
        durationHistory: [],
        trend: .unknown
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

    func detailedStats(
        for hearingAidId: UUID,
        recentWindowSize: Int = 10,
        historyLimit: Int = 20,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> DetailedBatteryStats {
        let logs = sortedLogs(for: hearingAidId, context: context)
        guard logs.count > 1 else { return .empty }

        let allDurations = durations(from: logs, windowSize: 0)
        let recentDurations = Array(allDurations.prefix(recentWindowSize))

        let snapshot = statsSnapshot(from: logs, sampleDurations: recentDurations, referenceDate: referenceDate)

        let allTimeAvg = allDurations.isEmpty ? nil : allDurations.reduce(0, +) / Double(allDurations.count)
        let recentAvg = recentDurations.isEmpty ? nil : recentDurations.reduce(0, +) / Double(recentDurations.count)
        let minDuration = allDurations.min()
        let maxDuration = allDurations.max()

        // Build history data points (most recent first, but we want oldest first for chart)
        var historyPoints: [DurationDataPoint] = []
        let limitedLogs = Array(logs.prefix(historyLimit + 1))
        for (index, log) in limitedLogs.enumerated() {
            guard index > 0 else { continue }
            let newerLog = limitedLogs[index - 1]
            guard log.excludeFromStats == false else { continue }
            guard newerLog.excludePreviousGapFromStats == false else { continue }
            let duration = newerLog.timestamp.timeIntervalSince(log.timestamp)
            guard duration > 0 else { continue }
            historyPoints.append(DurationDataPoint(
                id: log.id,
                index: historyPoints.count,
                duration: duration,
                timestamp: log.timestamp
            ))
        }
        // Reverse so oldest is first (index 0 = oldest)
        historyPoints = historyPoints.reversed().enumerated().map { index, point in
            DurationDataPoint(id: point.id, index: index, duration: point.duration, timestamp: point.timestamp)
        }

        // Calculate trend (compare first half avg to second half avg of recent durations)
        let trend: DetailedBatteryStats.Trend
        if recentDurations.count >= 4 {
            let midpoint = recentDurations.count / 2
            let olderHalf = Array(recentDurations.suffix(midpoint))
            let newerHalf = Array(recentDurations.prefix(midpoint))
            let olderAvg = olderHalf.reduce(0, +) / Double(olderHalf.count)
            let newerAvg = newerHalf.reduce(0, +) / Double(newerHalf.count)
            let changePercent = (newerAvg - olderAvg) / olderAvg
            if changePercent > 0.05 {
                trend = .improving
            } else if changePercent < -0.05 {
                trend = .declining
            } else {
                trend = .stable
            }
        } else {
            trend = .unknown
        }

        return DetailedBatteryStats(
            snapshot: snapshot,
            allTimeAvgDuration: allTimeAvg,
            recentAvgDuration: recentAvg,
            minDuration: minDuration,
            maxDuration: maxDuration,
            totalBatteriesUsed: max(0, logs.count - 1),
            durationHistory: historyPoints,
            trend: trend
        )
    }
}
