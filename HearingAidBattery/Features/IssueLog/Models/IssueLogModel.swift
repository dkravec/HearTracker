//
//  IssueLogModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

@Model
final class IssueLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()

    var issue: String = ""
    var severity: Int?               // 1–5
    var note: String?

    var hearingAid: HearingAid?
    var linkedBatteryLogId: UUID?    // optional link to “current” at time of issue

    init(hearingAid: HearingAid,
         timestamp: Date = Date(),
         issue: String,
         severity: Int? = nil,
         note: String? = nil) {
        self.hearingAid = hearingAid
        self.timestamp = timestamp
        self.issue = issue
        self.severity = severity
        self.note = note
    }
}
