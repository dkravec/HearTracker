//
//  HearingAidModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class HearingAid {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var name: String = ""
    var model: String?
    var batteryType: String?
    var retired: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \BatteryLog.hearingAid)
    var logs: [BatteryLog]?

    @Relationship(deleteRule: .cascade, inverse: \IssueLog.hearingAid)
    var issues: [IssueLog]?

    init(name: String, model: String? = nil, batteryType: String? = nil, retired: Bool = false) {
        self.name = name
        self.model = model
        self.batteryType = batteryType
        self.retired = retired
    }
}
