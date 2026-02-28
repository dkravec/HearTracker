//
//  BatteryLogModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import Foundation
import SwiftData

/// Lightweight value used for programmatic navigation to a battery-log detail screen.
struct BatteryLogRoute: Hashable {
    let logId: UUID
    let hearingAidId: UUID
}

@Model
final class BatteryLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var note: String?
    
    // If true, duration to the next log is excluded
    var excludeFromStats: Bool = false
    
    // If true, duration from previous log to this log is excluded
    var excludePreviousGapFromStats: Bool = false

    // Link to compute duration: previous log points to the next (newer) log
    var hearingAid: HearingAid?

    init(
        hearingAid: HearingAid,
        timestamp: Date = Date(),
        note: String? = nil,
        excludeFromStats: Bool = false,
        excludePreviousGapFromStats: Bool = false
    ) {
        self.hearingAid = hearingAid
        self.timestamp = timestamp
        self.note = note
        self.excludeFromStats = excludeFromStats
        self.excludePreviousGapFromStats = excludePreviousGapFromStats
    }
}
