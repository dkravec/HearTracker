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
    var spaceId: UUID = Space.defaultSpaceId
    var timestamp: Date = Date()

    var issue: String = ""
    var severity: Int?               // 1–5
    var note: String?
    var isResolved: Bool = false
    var resolvedAt: Date?
    var resolutionNote: String?

    var hearingAid: HearingAid?
    var linkedBatteryLogId: UUID?    // optional link to “current” at time of issue

    init(
        spaceId: UUID = Space.defaultSpaceId,
        hearingAid: HearingAid,
        timestamp: Date = Date(),
        issue: String,
        severity: Int? = nil,
        note: String? = nil,
        isResolved: Bool = false,
        resolvedAt: Date? = nil,
        resolutionNote: String? = nil
    ) {
        self.spaceId = spaceId
        self.hearingAid = hearingAid
        self.timestamp = timestamp
        self.issue = issue
        self.severity = severity
        self.note = note
        self.isResolved = isResolved
        self.resolvedAt = resolvedAt
        self.resolutionNote = resolutionNote
    }
}
