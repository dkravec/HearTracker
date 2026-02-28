import Foundation
import SwiftData
import Testing
@testable import HearingAidBattery

@MainActor
struct BackupServicesTests {
    @Test
    func exportImportRoundTripPreservesCoreCounts() throws {
        let sourceContainer = try makeContainer()
        let sourceContext = ModelContext(sourceContainer)

        let aid = HearingAid(name: "Right Aid", model: "M1", batteryType: "312", retired: false)
        let pack = BatteryPack(
            batteryType: "312",
            purchaseDate: Date(timeIntervalSince1970: 100),
            batteriesPerPack: 6,
            numberOfPacks: 2,
            priceAmount: Decimal(string: "12.50"),
            currencyCode: "USD",
            brand: "Power"
        )
        let log = BatteryLog(
            hearingAid: aid,
            timestamp: Date(timeIntervalSince1970: 200),
            note: "Changed"
        )
        log.batteryPack = pack

        let issue = IssueLog(
            hearingAid: aid,
            timestamp: Date(timeIntervalSince1970: 300),
            issue: "Static",
            severity: 3,
            note: "Intermittent"
        )

        let notification = NotificationModel(isEnabled: true, morningHour: 7, morningMinute: 30)

        sourceContext.insert(aid)
        sourceContext.insert(pack)
        sourceContext.insert(log)
        sourceContext.insert(issue)
        sourceContext.insert(notification)
        try sourceContext.save()

        let exportService = BackupExportService()
        let data = try exportService.exportJSONData(context: sourceContext)

        let targetContainer = try makeContainer()
        let targetContext = ModelContext(targetContainer)
        let importService = BackupImportService()
        try importService.importJSONData(data, context: targetContext)

        #expect(((try? targetContext.fetch(FetchDescriptor<HearingAid>())) ?? []).count == 1)
        #expect(((try? targetContext.fetch(FetchDescriptor<BatteryLog>())) ?? []).count == 1)
        #expect(((try? targetContext.fetch(FetchDescriptor<BatteryPack>())) ?? []).count == 1)
        #expect(((try? targetContext.fetch(FetchDescriptor<IssueLog>())) ?? []).count == 1)
        #expect(((try? targetContext.fetch(FetchDescriptor<NotificationModel>())) ?? []).count == 1)
    }

    @Test
    func importRejectsUnknownBackupFormatVersion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let data = try exportedData(context: context)
        let modifiedData = try mutateJSON(data) { root in
            root["backupFormatVersion"] = 999
        }

        assertImportError(
            modifiedData,
            in: context,
            failureMessage: "Expected unsupported backup format version error"
        ) { error in
            if case .unsupportedBackupFormatVersion(999) = error { return true }
            return false
        }
    }

    @Test
    func importRejectsUnknownModelVersion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let data = try exportedData(context: context)
        let modifiedData = try mutateJSON(data) { root in
            if var models = root["models"] as? [String: Any],
               var hearingAids = models["hearingAids"] as? [String: Any] {
                hearingAids["version"] = 999
                models["hearingAids"] = hearingAids
                root["models"] = models
            }
        }

        assertImportError(
            modifiedData,
            in: context,
            failureMessage: "Expected unsupported model version error"
        ) { error in
            if case .unsupportedModelVersion(model: "hearingAids", version: 999) = error { return true }
            return false
        }
    }

    @Test
    func importRejectsOrphanedBatteryLogReference() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let data = try exportedData(context: context)
        let modifiedData = try mutateJSON(data) { root in
            let aidId = UUID().uuidString
            let logId = UUID().uuidString

            if var models = root["models"] as? [String: Any] {
                models["hearingAids"] = [
                    "version": 1,
                    "items": []
                ]
                models["batteryLogs"] = [
                    "version": 1,
                    "items": [[
                        "id": logId,
                        "hearingAidId": aidId,
                        "batteryPackId": NSNull(),
                        "timestamp": "2026-02-28T00:00:00Z",
                        "note": NSNull(),
                        "excludeFromStats": false,
                        "excludePreviousGapFromStats": false,
                        "batteryType": NSNull()
                    ]]
                ]
                root["models"] = models
            }
        }

        assertImportError(
            modifiedData,
            in: context,
            failureMessage: "Expected unresolved reference error"
        ) { error in
            if case .unresolvedReference(model: "batteryLogs", field: "hearingAidId", id: _) = error { return true }
            return false
        }
    }

    @Test
    func importRejectsDuplicateBatteryLogIDs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let data = try exportedData(context: context)
        let duplicateId = UUID()
        let duplicateIdString = duplicateId.uuidString
        let aidId = UUID().uuidString
        let modifiedData = try mutateJSON(data) { root in
            if var models = root["models"] as? [String: Any] {
                models["hearingAids"] = [
                    "version": 1,
                    "items": [[
                        "id": aidId,
                        "createdAt": "2026-02-28T00:00:00Z",
                        "name": "Aid",
                        "model": NSNull(),
                        "batteryType": NSNull(),
                        "retired": false
                    ]]
                ]
                models["batteryLogs"] = [
                    "version": 1,
                    "items": [
                        [
                            "id": duplicateIdString,
                            "hearingAidId": aidId,
                            "batteryPackId": NSNull(),
                            "timestamp": "2026-02-28T00:00:00Z",
                            "note": NSNull(),
                            "excludeFromStats": false,
                            "excludePreviousGapFromStats": false,
                            "batteryType": NSNull()
                        ],
                        [
                            "id": duplicateIdString,
                            "hearingAidId": aidId,
                            "batteryPackId": NSNull(),
                            "timestamp": "2026-02-28T01:00:00Z",
                            "note": NSNull(),
                            "excludeFromStats": false,
                            "excludePreviousGapFromStats": false,
                            "batteryType": NSNull()
                        ]
                    ]
                ]
                root["models"] = models
            }
        }

        assertImportError(
            modifiedData,
            in: context,
            failureMessage: "Expected duplicate model id error"
        ) { error in
            if case .duplicateModelID(model: "batteryLogs", id: duplicateId) = error { return true }
            return false
        }
    }

    @Test
    func analyzeAndResolveIssueLinkedBatteryLogConflicts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let issueId = UUID()
        let missingLinkedLogId = UUID()
        let replacementLogId = UUID()
        let aidId = UUID()
        let data = try exportedData(context: context)
        let modifiedData = try mutateJSON(data) { root in
            if var models = root["models"] as? [String: Any] {
                models["hearingAids"] = [
                    "version": 1,
                    "items": [[
                        "id": aidId.uuidString,
                        "createdAt": "2026-02-28T00:00:00Z",
                        "name": "Right Aid",
                        "model": NSNull(),
                        "batteryType": NSNull(),
                        "retired": false
                    ]]
                ]
                models["batteryLogs"] = [
                    "version": 1,
                    "items": [[
                        "id": replacementLogId.uuidString,
                        "hearingAidId": aidId.uuidString,
                        "batteryPackId": NSNull(),
                        "timestamp": "2026-02-28T01:00:00Z",
                        "note": "Replacement",
                        "excludeFromStats": false,
                        "excludePreviousGapFromStats": false,
                        "batteryType": NSNull()
                    ]]
                ]
                models["issueLogs"] = [
                    "version": 1,
                    "items": [[
                        "id": issueId.uuidString,
                        "hearingAidId": aidId.uuidString,
                        "timestamp": "2026-02-28T02:00:00Z",
                        "issue": "Static",
                        "severity": 2,
                        "note": NSNull(),
                        "linkedBatteryLogId": missingLinkedLogId.uuidString
                    ]]
                ]
                root["models"] = models
            }
        }

        let importService = BackupImportService()
        let analysis = try importService.analyzeIssueLinkConflicts(in: modifiedData)
        #expect(analysis.conflicts.count == 1)
        #expect(analysis.candidates.count == 1)
        #expect(analysis.conflicts.first?.issueLogId == issueId)

        let summary = try importService.importJSONData(
            modifiedData,
            context: context,
            issueLogLinkedBatteryLogOverrides: [issueId: replacementLogId]
        )
        #expect(summary.issueLogs == 1)

        let issues = try context.fetch(FetchDescriptor<IssueLog>())
        #expect(issues.count == 1)
        #expect(issues.first?.linkedBatteryLogId == replacementLogId)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([
                HearingAid.self,
                BatteryLog.self,
                BatteryPack.self,
                IssueLog.self,
                NotificationModel.self,
            ]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func mutateJSON(_ data: Data, mutate: (inout [String: Any]) -> Void) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupImportService.BackupImportError.decodingFailed
        }
        mutate(&root)
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private func exportedData(context: ModelContext) throws -> Data {
        let exportService = BackupExportService()
        return try exportService.exportJSONData(context: context)
    }

    private func assertImportError(
        _ data: Data,
        in context: ModelContext,
        failureMessage: String,
        matches: (BackupImportService.BackupImportError) -> Bool
    ) {
        let importService = BackupImportService()
        do {
            try importService.importJSONData(data, context: context)
            Issue.record(failureMessage)
        } catch let error as BackupImportService.BackupImportError {
            #expect(matches(error))
        } catch {
            Issue.record("Unexpected non-import error: \(error)")
        }
    }
}
