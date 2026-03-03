import Foundation
import SwiftData

@MainActor
struct NotesImportCommitService {
    func commit(
        items: [NotesImportPreviewItem],
        hearingAid: HearingAid,
        context: ModelContext
    ) throws -> NotesImportCommitResult {
        let issueService = IssueLogService()
        var createdBatteryLogs = 0
        var createdIssues = 0
        var skippedDuplicates = 0
        var unresolvedSkipped = 0

        for item in items {
            guard let timestamp = item.resolvedTimestamp else {
                unresolvedSkipped += 1
                continue
            }

            let noteText = normalized(item.note)

            switch item.kind {
            case .battery:
                if batteryLogExists(
                    timestamp: timestamp,
                    note: noteText,
                    hearingAidId: hearingAid.id,
                    spaceId: hearingAid.spaceId,
                    context: context
                ) {
                    skippedDuplicates += 1
                    continue
                }

                let log = BatteryLog(
                    spaceId: hearingAid.spaceId,
                    hearingAid: hearingAid,
                    timestamp: timestamp,
                    note: noteText
                )
                context.insert(log)
                createdBatteryLogs += 1

            case .issue:
                let issueText = noteText
                    ?? normalized(item.originalLine)
                    ?? "Imported issue"

                if issueExists(
                    timestamp: timestamp,
                    issue: issueText,
                    hearingAidId: hearingAid.id,
                    spaceId: hearingAid.spaceId,
                    context: context
                ) {
                    skippedDuplicates += 1
                    continue
                }

                try issueService.createIssueLog(
                    for: hearingAid,
                    timestamp: timestamp,
                    issue: issueText,
                    severity: nil,
                    note: noteText,
                    linkedBatteryLogId: nil,
                    context: context
                )
                createdIssues += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }

        return NotesImportCommitResult(
            createdBatteryLogs: createdBatteryLogs,
            createdIssues: createdIssues,
            skippedDuplicates: skippedDuplicates,
            unresolvedSkipped: unresolvedSkipped
        )
    }

    private func batteryLogExists(
        timestamp: Date,
        note: String?,
        hearingAidId: UUID,
        spaceId: UUID,
        context: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<BatteryLog>(
            predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId && $0.spaceId == spaceId },
            sortBy: [SortDescriptor(\BatteryLog.timestamp, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.contains {
            $0.timestamp == timestamp && normalized($0.note) == note
        }
    }

    private func issueExists(
        timestamp: Date,
        issue: String,
        hearingAidId: UUID,
        spaceId: UUID,
        context: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<IssueLog>(
            predicate: #Predicate<IssueLog> { $0.hearingAid?.id == hearingAidId && $0.spaceId == spaceId },
            sortBy: [SortDescriptor(\IssueLog.timestamp, order: .reverse)]
        )
        let issues = (try? context.fetch(descriptor)) ?? []
        return issues.contains {
            $0.timestamp == timestamp && normalized($0.issue) == issue
        }
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, trimmed.isEmpty == false else { return nil }
        return trimmed
    }
}
