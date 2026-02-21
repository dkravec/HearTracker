//
//  BatteryLog.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class BatteryLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var note: String?

    // “current” points to the latest log for that device
    var isCurrent: Bool = true

    // Link to compute duration: previous log points to the next (newer) log
    var nextLogId: UUID?

    var hearingAid: HearingAid?

    init(hearingAid: HearingAid, timestamp: Date = Date(), note: String? = nil, isCurrent: Bool = true) {
        self.timestamp = timestamp
        self.note = note
        self.isCurrent = isCurrent
        self.nextLogId = nil
        self.hearingAid = hearingAid
    }
}
