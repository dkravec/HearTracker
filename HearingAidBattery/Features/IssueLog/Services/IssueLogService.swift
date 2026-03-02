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
        timestamp: Date = Date(),
        issue: String,
        severity: Int? = nil,
        note: String? = nil,
        linkedBatteryLogId: UUID? = nil,
        context: ModelContext
    ) throws {
        let issueLog = IssueLog(
            hearingAid: hearingAid,
            timestamp: timestamp,
            issue: issue.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: severity,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        issueLog.linkedBatteryLogId = linkedBatteryLogId

        context.insert(issueLog)
        try context.save()
    }

    func updateIssue(
        _ issueLog: IssueLog,
        timestamp: Date,
        issue: String,
        severity: Int?,
        note: String?,
        context: ModelContext
    ) throws {
        issueLog.timestamp = timestamp
        issueLog.issue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
        issueLog.severity = normalizedSeverity(severity)
        issueLog.note = normalizedOptionalText(note)
        try context.save()
    }

    func deleteIssue(_ issueLog: IssueLog, context: ModelContext) throws {
        context.delete(issueLog)
        try context.save()
    }

    /// Convenience: resolves the hearing aid, links to the latest battery log,
    /// and creates the issue in one call. Shared by AddEntryChoiceSheet and
    /// IssueLogListView so the save logic isn't duplicated.
    func saveFromSheet(
        aids: [HearingAid],
        singleAid: HearingAid? = nil,
        hearingAidId: UUID?,
        timestamp: Date,
        issue: String,
        severity: Int?,
        note: String?,
        context: ModelContext
    ) throws {
        let targetAid: HearingAid? = {
            if let singleAid { return singleAid }
            guard let hearingAidId else { return nil }
            return aids.first(where: { $0.id == hearingAidId })
        }()
        guard let targetAid else { return }

        let targetAidId = targetAid.id
        var descriptor = FetchDescriptor<BatteryLog>(
            predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == targetAidId },
            sortBy: [SortDescriptor(\BatteryLog.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let currentLogId = (try? context.fetch(descriptor))?.first?.id

        try createIssueLog(
            for: targetAid,
            timestamp: timestamp,
            issue: issue,
            severity: normalizedSeverity(severity),
            note: note,
            linkedBatteryLogId: currentLogId,
            context: context
        )
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedSeverity(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return min(5, max(1, value))
    }
}
