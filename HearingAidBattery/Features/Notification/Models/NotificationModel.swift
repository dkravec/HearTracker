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
    var morningHour: Int = 8
    var morningMinute: Int = 0

    init(
        isEnabled: Bool = false,
        morningHour: Int = 8,
        morningMinute: Int = 0
    ) {
        self.isEnabled = isEnabled
        self.morningHour = morningHour
        self.morningMinute = morningMinute
    }
}
