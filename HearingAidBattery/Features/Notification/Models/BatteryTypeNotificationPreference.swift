//
//  BatteryTypeNotificationPreference.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-04.
//

import Foundation
import SwiftData

@Model
final class BatteryTypeNotificationPreference {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var spaceId: UUID = Space.defaultSpaceId
    var batteryType: String = ""
    var notificationsOn: Bool = true
    var sentFinal: Bool = false

    init(
        spaceId: UUID = Space.defaultSpaceId,
        batteryType: String,
        notificationsOn: Bool = true,
        sentFinal: Bool = false
    ) {
        self.spaceId = spaceId
        self.batteryType = batteryType
        self.notificationsOn = notificationsOn
        self.sentFinal = sentFinal
    }
}
