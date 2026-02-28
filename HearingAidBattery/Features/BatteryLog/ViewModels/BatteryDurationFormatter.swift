//
//  BatteryDurationFormatter.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation

struct BatteryDurationFormatter {
    private let relativeDateFormatter: RelativeDateTimeFormatter

    init() {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        self.relativeDateFormatter = formatter
    }

    func daysText(from duration: TimeInterval) -> String {
        String(format: "%.1f days", duration / 86_400.0)
    }

    func optionalDaysText(from duration: TimeInterval?) -> String? {
        guard let duration else { return nil }
        return daysText(from: duration)
    }

    func relativeDateText(from date: Date, referenceDate: Date = Date()) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: referenceDate)
    }
}
