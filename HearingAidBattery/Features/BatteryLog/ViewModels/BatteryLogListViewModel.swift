//
//  BatteryLogListViewModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Combine
import Foundation

struct BatteryLogRowModel: Identifiable {
    let id: UUID
    let isCurrent: Bool
    let rawDuration: TimeInterval?
    let durationText: String?
}

@MainActor
final class BatteryLogListViewModel: ObservableObject {
    @Published private(set) var rows: [BatteryLogRowModel] = []

    private let formatter: BatteryDurationFormatter

    init(formatter: BatteryDurationFormatter) {
        self.formatter = formatter
    }

    convenience init() {
        self.init(formatter: BatteryDurationFormatter())
    }

    func refresh(sortedLogs: [BatteryLog], currentLogId: UUID?) {
        rows = sortedLogs.enumerated().map { index, log in
            let duration = duration(forIndex: index, in: sortedLogs)
            return BatteryLogRowModel(
                id: log.id,
                isCurrent: log.id == currentLogId,
                rawDuration: duration,
                durationText: formatter.optionalDaysText(from: duration)
            )
        }
    }

    private func duration(forIndex index: Int, in sortedLogs: [BatteryLog]) -> TimeInterval? {
        guard index > 0 else { return nil }

        let log = sortedLogs[index]
        let newerLog = sortedLogs[index - 1]
        let interval = newerLog.timestamp.timeIntervalSince(log.timestamp)
        return interval > 0 ? interval : nil
    }
}
