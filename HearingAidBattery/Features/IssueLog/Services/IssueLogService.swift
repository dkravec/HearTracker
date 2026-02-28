//
//  IssueLogService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

@MainActor
final class IssueLogService {
    func createIssueLog(
        for hearingAid: HearingAid,
        category: String,
        severity: Int? = nil,
        note: String? = nil,
        linkedBatteryLogId: UUID? = nil,
        context: ModelContext
    ) throws {
        let issueLog = IssueLog(
            hearingAid: hearingAid,
            category: category,
            severity: severity,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        issueLog.linkedBatteryLogId = linkedBatteryLogId

        context.insert(issueLog)
        try context.save()
    }

    func deleteIssueLog(_ issueLog: IssueLog, context: ModelContext) throws {
        context.delete(issueLog)
        try context.save()
    }
}
