//
//  NotificationModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation
import SwiftData

@Model
final class NotificationModel {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var isEnabled: Bool = false
    var isExpectedDeathWarningEnabled: Bool = true
    var expectedDeathWarningHours: Int = 1
    var expectedDeathWarningMinutes: Int = 0
    var isMorningHeadsUpEnabled: Bool = true
    var morningHour: Int = 8
    var morningMinute: Int = 0
    var isLowBatteryPackWarningEnabled: Bool = true
    var lowBatteryPackThreshold: Int = 4

    init(
        isEnabled: Bool = false,
        isExpectedDeathWarningEnabled: Bool = true,
        expectedDeathWarningHours: Int = 1,
        expectedDeathWarningMinutes: Int = 0,
        isMorningHeadsUpEnabled: Bool = true,
        morningHour: Int = 8,
        morningMinute: Int = 0,
        isLowBatteryPackWarningEnabled: Bool = true,
        lowBatteryPackThreshold: Int = 4
    ) {
        self.isEnabled = isEnabled
        self.isExpectedDeathWarningEnabled = isExpectedDeathWarningEnabled
        self.expectedDeathWarningHours = expectedDeathWarningHours
        self.expectedDeathWarningMinutes = expectedDeathWarningMinutes
        self.isMorningHeadsUpEnabled = isMorningHeadsUpEnabled
        self.morningHour = morningHour
        self.morningMinute = morningMinute
        self.isLowBatteryPackWarningEnabled = isLowBatteryPackWarningEnabled
        self.lowBatteryPackThreshold = max(1, lowBatteryPackThreshold)
    }
}
