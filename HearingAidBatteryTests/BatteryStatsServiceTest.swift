//
//  BatteryStatsServiceTest.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData
import Testing
@testable import HearingAidBattery

@MainActor
struct BatteryStatsServiceTests {
    @Test
    // Verifies the newest timestamp is treated as the current battery log.
    func currentLogSelectionUsesNewestTimestamp() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let older = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))
        let newer = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 2_000))

        let snapshot = service.statsSnapshot(from: [newer, older], windowSize: 0, referenceDate: Date(timeIntervalSince1970: 3_000))

        #expect(snapshot.currentLogId == newer.id)
        #expect(snapshot.currentAge == 1_000)
    }

    @Test
    // Verifies completed durations are only formed from logs that have a newer neighbor.
    func durationsExcludeCurrentLogWithoutNextLog() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let current = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 4_000))
        let previous = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000))
        let old = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))

        let snapshot = service.statsSnapshot(from: [current, previous, old], windowSize: 0, referenceDate: Date(timeIntervalSince1970: 5_000))

        #expect(snapshot.sampleCount == 2)
        #expect(snapshot.avgDuration == 1_500)
    }

    @Test
    // Verifies the rolling window keeps only the most recent N completed durations.
    func rollingWindowUsesMostRecentNDurations() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let current = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 40_000))
        let log2 = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 30_000))
        let log3 = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 15_000))
        let log4 = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 5_000))

        let snapshot = service.statsSnapshot(from: [current, log2, log3, log4], windowSize: 2, referenceDate: Date(timeIntervalSince1970: 50_000))

        #expect(snapshot.sampleCount == 2)
        #expect(snapshot.avgDuration == 12_500)
    }

    @Test
    // Verifies prediction is computed as current log timestamp plus average duration.
    func predictedDeathEqualsCurrentInsertedAtPlusAverageDuration() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let current = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 100_000))
        let previous = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 90_000))

        let snapshot = service.statsSnapshot(from: [current, previous], windowSize: 1, referenceDate: Date(timeIntervalSince1970: 100_500))

        #expect(snapshot.avgDuration == 10_000)
        #expect(snapshot.predictedDeath == Date(timeIntervalSince1970: 110_000))
    }

    @Test
    // Verifies excludeFromStats=true removes that battery interval from samples.
    func excludeFromStatsTrueExcludesThatBatteryDuration() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let current = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 4_000))
        let previous = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000), excludeFromStats: true)
        let old = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))

        let snapshot = service.statsSnapshot(from: [current, previous, old], windowSize: 0, referenceDate: Date(timeIntervalSince1970: 5_000))

        #expect(snapshot.sampleCount == 1)
        #expect(snapshot.avgDuration == 2_000)
    }

    @Test
    // Verifies excludePreviousGapFromStats=true removes the incoming gap into that log.
    func excludePreviousGapFromStatsExcludesIncomingDuration() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let current = BatteryLog(
            hearingAid: aid,
            timestamp: Date(timeIntervalSince1970: 4_000),
            excludePreviousGapFromStats: true
        )
        let previous = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000))
        let old = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))

        let snapshot = service.statsSnapshot(from: [current, previous, old], windowSize: 0, referenceDate: Date(timeIntervalSince1970: 5_000))

        #expect(snapshot.sampleCount == 1)
        #expect(snapshot.avgDuration == 2_000)
    }

    @Test
    // Verifies sortedLogs returns logs in reverse-chronological order.
    func sortedLogsReturnsNewestFirst() throws {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")
        let container = try ModelContainer(
            for: Schema([HearingAid.self, BatteryLog.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let older = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))
        let newer = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 2_000))
        context.insert(aid)
        context.insert(older)
        context.insert(newer)
        try context.save()

        let sorted = service.sortedLogs(for: aid.id, context: context)
        #expect(sorted.map(\.id) == [newer.id, older.id])
    }

    @Test
    // Verifies raw APIs compute durations, average, prediction, and age consistently.
    func rawApisReturnExpectedValues() throws {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")
        let container = try ModelContainer(
            for: Schema([HearingAid.self, BatteryLog.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let current = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 4_000))
        let previous = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000))
        let old = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))
        context.insert(aid)
        context.insert(current)
        context.insert(previous)
        context.insert(old)
        try context.save()

        let durations = service.durations(for: aid.id, windowSize: 0, context: context)
        let average = service.averageDuration(for: aid.id, windowSize: 0, context: context)
        let predicted = service.predictedDeath(for: aid.id, windowSize: 0, context: context)
        let age = service.currentBatteryAge(
            for: aid.id,
            context: context,
            referenceDate: Date(timeIntervalSince1970: 5_000)
        )

        #expect(durations == [1_000, 2_000])
        #expect(average == 1_500)
        #expect(predicted == Date(timeIntervalSince1970: 5_500))
        #expect(age == 1_000)
    }

    @Test
    // Verifies the status view model mirrors values from its stats provider.
    func batteryStatusViewModelUsesProviderSnapshot() throws {
        let expectedSnapshot = BatteryStatsSnapshot(
            currentLogId: UUID(),
            currentAge: 120,
            avgDuration: 10_000,
            predictedDeath: Date(timeIntervalSince1970: 12_000),
            sampleCount: 3
        )

        let provider = InMemoryBatteryStatsProvider(snapshot: expectedSnapshot)
        let viewModel = BatteryStatusViewModel(statsProvider: provider, formatter: BatteryDurationFormatter())

        let container = try ModelContainer(
            for: Schema([HearingAid.self, BatteryLog.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        _ = viewModel.refresh(hearingAidId: UUID(), windowSize: 5, context: context)

        #expect(viewModel.avgDuration == expectedSnapshot.avgDuration)
        #expect(viewModel.predictedDeath == expectedSnapshot.predictedDeath)
        #expect(viewModel.currentBatteryAge == expectedSnapshot.currentAge)
        #expect(viewModel.sampleCount == expectedSnapshot.sampleCount)
    }

    @Test
    // Verifies a single log has no completed samples while still reporting current battery age.
    func singleLogProducesNoAverageOrPredictionButKeepsCurrentAge() throws {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")
        let container = try ModelContainer(
            for: Schema([HearingAid.self, BatteryLog.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let onlyLog = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 4_000))
        context.insert(aid)
        context.insert(onlyLog)
        try context.save()

        let snapshot = service.statsSnapshot(
            for: aid.id,
            windowSize: 10,
            context: context,
            referenceDate: Date(timeIntervalSince1970: 5_000)
        )

        #expect(snapshot.sampleCount == 0)
        #expect(snapshot.avgDuration == nil)
        #expect(snapshot.predictedDeath == nil)
        #expect(snapshot.currentAge == 1_000)
    }

    @Test
    // Verifies equal or reversed timestamps do not create invalid samples and newest log remains current.
    func nonPositiveDurationsAreIgnoredAndNewestLogRemainsCurrent() throws {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")
        let container = try ModelContainer(
            for: Schema([HearingAid.self, BatteryLog.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let newest = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 4_000))
        let equalA = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000))
        let equalB = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000))
        let oldest = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))

        // Insert out of order to ensure fetch sorting defines the evaluation order.
        context.insert(aid)
        context.insert(equalA)
        context.insert(newest)
        context.insert(oldest)
        context.insert(equalB)
        try context.save()

        let snapshot = service.statsSnapshot(
            for: aid.id,
            windowSize: 0,
            context: context,
            referenceDate: Date(timeIntervalSince1970: 5_000)
        )

        #expect(snapshot.currentLogId == newest.id)
        #expect(snapshot.sampleCount == 2)
        #expect(snapshot.avgDuration == 1_500)
        #expect(snapshot.predictedDeath == Date(timeIntervalSince1970: 5_500))
    }

}

@MainActor
private struct InMemoryBatteryStatsProvider: BatteryStatsProviding {
    let snapshot: BatteryStatsSnapshot

    func statsSnapshot(
        for hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date
    ) -> BatteryStatsSnapshot {
        snapshot
    }
}
