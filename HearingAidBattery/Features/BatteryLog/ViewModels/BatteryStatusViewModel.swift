//
//  BatteryStatusViewModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class BatteryStatusViewModel: ObservableObject {
    @Published private(set) var avgDuration: TimeInterval?
    @Published private(set) var predictedDeath: Date?
    @Published private(set) var currentBatteryAge: TimeInterval?
    @Published private(set) var sampleCount: Int = 0

    private let statsProvider: BatteryStatsProviding
    private let formatter: BatteryDurationFormatter

    init(statsProvider: BatteryStatsProviding, formatter: BatteryDurationFormatter) {
        self.statsProvider = statsProvider
        self.formatter = formatter
    }

    convenience init() {
        self.init(statsProvider: BatteryStatsService(), formatter: BatteryDurationFormatter())
    }

    var averageDurationText: String? {
        formatter.optionalDaysText(from: avgDuration)
    }

    var currentBatteryAgeText: String? {
        formatter.optionalDaysText(from: currentBatteryAge)
    }

    var predictedDeathText: String? {
        guard let predictedDeath else { return nil }
        return formatter.relativeDateText(from: predictedDeath)
    }

    @discardableResult
    func refresh(
        hearingAidId: UUID,
        windowSize: Int,
        context: ModelContext,
        referenceDate: Date = Date()
    ) -> BatteryStatsSnapshot {
        let snapshot = statsProvider.statsSnapshot(
            for: hearingAidId,
            windowSize: windowSize,
            context: context,
            referenceDate: referenceDate
        )

        avgDuration = snapshot.avgDuration
        predictedDeath = snapshot.predictedDeath
        currentBatteryAge = snapshot.currentAge
        sampleCount = snapshot.sampleCount

        return snapshot
    }
}
