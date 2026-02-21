//
//  HearingAid.swift
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
    var retired: Bool = false

    // Derived (don’t store batteryChanges unless you really want cached counts)
    @Relationship(deleteRule: .cascade, inverse: \BatteryLog.hearingAid)
    var logs: [BatteryLog]? = []

    init(name: String, model: String? = nil, retired: Bool = false) {
        self.name = name
        self.model = model
        self.retired = retired
        self.logs = []
    }

    var batteryChangeCount: Int { logs?.count ?? 0 }
}
