import Foundation
import SwiftData

struct BackupImportSummary {
    let hearingAids: Int
    let batteryLogs: Int
    let batteryPacks: Int
    let issueLogs: Int
    let notifications: Int
}

struct BackupIssueLinkConflictAnalysis {
    let conflicts: [BackupIssueLinkConflict]
    let candidates: [BackupIssueLinkCandidate]
}

struct BackupIssueLinkConflict: Identifiable {
    let issueLogId: UUID
    let issueTimestamp: Date
    let issueText: String
    let hearingAidName: String?
    let missingLinkedBatteryLogId: UUID

    var id: UUID { issueLogId }
}

struct BackupIssueLinkCandidate: Identifiable {
    let id: UUID
    let timestamp: Date
    let hearingAidName: String?
    let note: String?
}

@MainActor
struct BackupImportService {
    enum BackupImportError: Error {
        case unsupportedBackupFormatVersion(Int)
        case unsupportedModelVersion(model: String, version: Int)
        case decodingFailed
        case duplicateModelID(model: String, id: UUID)
        case missingRequiredReference(model: String, field: String, id: UUID)
        case unresolvedReference(model: String, field: String, id: UUID)
    }

    private let supportedVersion = 1

    func importJSONData(
        _ data: Data,
        context: ModelContext,
        issueLogLinkedBatteryLogOverrides: [UUID: UUID?] = [:]
    ) throws -> BackupImportSummary {
        let envelope = try decodeAndValidateEnvelope(data)
        do {
            return try replaceAllData(
                with: envelope.models,
                context: context,
                issueLogLinkedBatteryLogOverrides: issueLogLinkedBatteryLogOverrides
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    func analyzeIssueLinkConflicts(in data: Data) throws -> BackupIssueLinkConflictAnalysis {
        let envelope = try decodeAndValidateEnvelope(data)
        var aidsById: [UUID: HearingAidDTO_v1] = [:]
        for aid in envelope.models.hearingAids.items {
            aidsById[aid.id] = aid
        }
        var batteryLogsById: [UUID: BatteryLogDTO_v1] = [:]
        for batteryLog in envelope.models.batteryLogs.items {
            batteryLogsById[batteryLog.id] = batteryLog
        }

        let candidates = envelope.models.batteryLogs.items.map { log in
            BackupIssueLinkCandidate(
                id: log.id,
                timestamp: log.timestamp,
                hearingAidName: log.hearingAidId.flatMap { aidsById[$0]?.name },
                note: log.note
            )
        }

        let conflicts = envelope.models.issueLogs.items.compactMap { issue -> BackupIssueLinkConflict? in
            guard let linkedBatteryLogId = issue.linkedBatteryLogId else { return nil }
            guard batteryLogsById[linkedBatteryLogId] == nil else { return nil }
            return BackupIssueLinkConflict(
                issueLogId: issue.id,
                issueTimestamp: issue.timestamp,
                issueText: issue.issue,
                hearingAidName: issue.hearingAidId.flatMap { aidsById[$0]?.name },
                missingLinkedBatteryLogId: linkedBatteryLogId
            )
        }

        return BackupIssueLinkConflictAnalysis(conflicts: conflicts, candidates: candidates)
    }

    private func validateModelVersions(_ models: BackupModels_v1) throws {
        try validateModelVersion(models.hearingAids.version, model: "hearingAids")
        try validateModelVersion(models.batteryLogs.version, model: "batteryLogs")
        try validateModelVersion(models.batteryPacks.version, model: "batteryPacks")
        try validateModelVersion(models.issueLogs.version, model: "issueLogs")
        try validateModelVersion(models.settings.version, model: "settings")
        try validateModelVersion(models.notifications.version, model: "notifications")
    }

    private func replaceAllData(
        with models: BackupModels_v1,
        context: ModelContext,
        issueLogLinkedBatteryLogOverrides: [UUID: UUID?]
    ) throws -> BackupImportSummary {
        let currentLogs = try context.fetch(FetchDescriptor<BatteryLog>())
        let currentIssues = try context.fetch(FetchDescriptor<IssueLog>())
        let currentPacks = try context.fetch(FetchDescriptor<BatteryPack>())
        let currentNotifications = try context.fetch(FetchDescriptor<NotificationModel>())
        let currentAids = try context.fetch(FetchDescriptor<HearingAid>())

        for item in currentLogs { context.delete(item) }
        for item in currentIssues { context.delete(item) }
        for item in currentPacks { context.delete(item) }
        for item in currentNotifications { context.delete(item) }
        for item in currentAids { context.delete(item) }

        let aidsById = try makeDictionary(items: models.hearingAids.items, modelName: "hearingAids") { dto in
            let aid = HearingAid(
                name: dto.name,
                model: dto.model,
                batteryType: dto.batteryType,
                retired: dto.retired,
                notificationsEnabled: dto.notificationsEnabled ?? true
            )
            aid.id = dto.id
            aid.createdAt = dto.createdAt
            context.insert(aid)
            return aid
        }

        let packsById = try makeDictionary(items: models.batteryPacks.items, modelName: "batteryPacks") { dto in
            let pack = BatteryPack(
                batteryType: dto.batteryType,
                purchaseDate: dto.purchaseDate,
                batteriesPerPack: dto.batteriesPerPack,
                numberOfPacks: dto.numberOfPacks,
                priceAmount: dto.priceAmount,
                currencyCode: dto.currencyCode,
                brand: dto.brand
            )
            pack.id = dto.id
            pack.createdAt = dto.createdAt
            pack.quantityPurchased = dto.quantityPurchased
            pack.quantityRemaining = dto.quantityRemaining
            pack.retailer = dto.retailer
            pack.note = dto.note
            context.insert(pack)
            return pack
        }

        let logsById = try makeDictionary(items: models.batteryLogs.items, modelName: "batteryLogs") { dto in
            let aidId = try requireReference(
                dto.hearingAidId,
                model: "batteryLogs",
                field: "hearingAidId",
                id: dto.id
            )
            guard let aid = aidsById[aidId] else {
                throw BackupImportError.unresolvedReference(
                    model: "batteryLogs",
                    field: "hearingAidId",
                    id: dto.id
                )
            }

            let log = BatteryLog(
                hearingAid: aid,
                timestamp: dto.timestamp,
                note: dto.note,
                excludeFromStats: dto.excludeFromStats,
                excludePreviousGapFromStats: dto.excludePreviousGapFromStats
            )
            log.id = dto.id
            log.batteryType = dto.batteryType
            if let packId = dto.batteryPackId {
                guard let pack = packsById[packId] else {
                    throw BackupImportError.unresolvedReference(
                        model: "batteryLogs",
                        field: "batteryPackId",
                        id: dto.id
                    )
                }
                log.batteryPack = pack
            }
            context.insert(log)
            return log
        }

        for dto in models.issueLogs.items {
            let aidId = try requireReference(
                dto.hearingAidId,
                model: "issueLogs",
                field: "hearingAidId",
                id: dto.id
            )
            guard let aid = aidsById[aidId] else {
                throw BackupImportError.unresolvedReference(
                    model: "issueLogs",
                    field: "hearingAidId",
                    id: dto.id
                )
            }
            let issue = IssueLog(
                hearingAid: aid,
                timestamp: dto.timestamp,
                issue: dto.issue,
                severity: dto.severity,
                note: dto.note
            )
            issue.id = dto.id
            if let linkedBatteryLogId = dto.linkedBatteryLogId {
                if logsById[linkedBatteryLogId] != nil {
                    issue.linkedBatteryLogId = linkedBatteryLogId
                } else if let override = issueLogLinkedBatteryLogOverrides[dto.id] {
                    if let override {
                        guard logsById[override] != nil else {
                            throw BackupImportError.unresolvedReference(
                                model: "issueLogs",
                                field: "linkedBatteryLogId",
                                id: dto.id
                            )
                        }
                        issue.linkedBatteryLogId = override
                    } else {
                        issue.linkedBatteryLogId = nil
                    }
                } else {
                    throw BackupImportError.unresolvedReference(
                        model: "issueLogs",
                        field: "linkedBatteryLogId",
                        id: dto.id
                    )
                }
            }
            context.insert(issue)
        }

        for dto in models.notifications.items {
            let notification = NotificationModel(
                isEnabled: dto.isEnabled,
                isExpectedDeathWarningEnabled: dto.isExpectedDeathWarningEnabled ?? true,
                expectedDeathWarningHours: dto.expectedDeathWarningHours ?? 1,
                expectedDeathWarningMinutes: dto.expectedDeathWarningMinutes ?? 0,
                isMorningHeadsUpEnabled: dto.isMorningHeadsUpEnabled ?? true,
                morningHour: dto.morningHour,
                morningMinute: dto.morningMinute
            )
            notification.id = dto.id
            notification.createdAt = dto.createdAt
            context.insert(notification)
        }

        try context.save()
        return BackupImportSummary(
            hearingAids: models.hearingAids.items.count,
            batteryLogs: models.batteryLogs.items.count,
            batteryPacks: models.batteryPacks.items.count,
            issueLogs: models.issueLogs.items.count,
            notifications: models.notifications.items.count
        )
    }

    private func makeDictionary<T, U>(
        items: [T],
        modelName: String,
        transform: (T) throws -> U
    ) throws -> [UUID: U] where T: HasID {
        var values: [UUID: U] = [:]
        values.reserveCapacity(items.count)
        for item in items {
            if values[item.id] != nil {
                throw BackupImportError.duplicateModelID(model: modelName, id: item.id)
            }
            values[item.id] = try transform(item)
        }
        return values
    }

    private func requireReference(
        _ value: UUID?,
        model: String,
        field: String,
        id: UUID
    ) throws -> UUID {
        guard let value else {
            throw BackupImportError.missingRequiredReference(model: model, field: field, id: id)
        }
        return value
    }

    private func validateModelVersion(_ version: Int, model: String) throws {
        guard version == supportedVersion else {
            throw BackupImportError.unsupportedModelVersion(model: model, version: version)
        }
    }

    private func decodeAndValidateEnvelope(_ data: Data) throws -> BackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: BackupEnvelope
        do {
            envelope = try decoder.decode(BackupEnvelope.self, from: data)
        } catch {
            throw BackupImportError.decodingFailed
        }

        guard envelope.backupFormatVersion == supportedVersion else {
            throw BackupImportError.unsupportedBackupFormatVersion(envelope.backupFormatVersion)
        }

        try validateModelVersions(envelope.models)
        return envelope
    }
}

private protocol HasID {
    var id: UUID { get }
}

extension HearingAidDTO_v1: HasID {}
extension BatteryLogDTO_v1: HasID {}
extension BatteryPackDTO_v1: HasID {}
