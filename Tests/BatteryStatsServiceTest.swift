//
//  BatteryStatsServiceTest.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

#if canImport(Testing)
import Foundation
import SwiftData
import Testing
@testable import HearingAidBattery

@MainActor
struct BatteryStatsServiceTests {
    @Test
    func currentLogSelectionUsesNewestTimestamp() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let older = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))
        let newer = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 2_000))

        let snapshot = service.statsSnapshot(from: [newer, older], windowSize: 0, referenceDate: Date(timeIntervalSince1970: 3_000))

        #expect(snapshot.currentLogId == newer.id)
        #expect(snapshot.currentInsertedAt == newer.timestamp)
    }

    @Test
    func durationsExcludeCurrentLogWithoutNextLog() {
        let service = BatteryStatsService()
        let aid = HearingAid(name: "A")

        let current = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 4_000))
        let previous = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 3_000))
        let old = BatteryLog(hearingAid: aid, timestamp: Date(timeIntervalSince1970: 1_000))

        let snapshot = service.statsSnapshot(from: [current, previous, old], windowSize: 0, referenceDate: Date(timeIntervalSince1970: 5_000))

        #expect(snapshot.sampleCount == 2)
        #expect(snapshot.lastCompletedDuration == 1_000)
    }

    @Test
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
    func batteryStatusViewModelUsesProviderSnapshot() throws {
        let expectedSnapshot = BatteryStatsSnapshot(
            currentLogId: UUID(),
            currentInsertedAt: Date(timeIntervalSince1970: 2_000),
            currentBatteryAge: 120,
            avgDuration: 10_000,
            predictedDeath: Date(timeIntervalSince1970: 12_000),
            sampleCount: 3,
            lastCompletedDuration: 9_000
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
        #expect(viewModel.currentBatteryAge == expectedSnapshot.currentBatteryAge)
        #expect(viewModel.sampleCount == expectedSnapshot.sampleCount)
        #expect(viewModel.lastCompletedDuration == expectedSnapshot.lastCompletedDuration)
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
#endif
