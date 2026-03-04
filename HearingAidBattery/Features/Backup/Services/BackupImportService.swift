import Foundation
import SwiftData

struct BackupImportSummary {
    let hearingAids: Int
    let batteryLogs: Int
    let batteryPacks: Int
    let issueLogs: Int
    let notifications: Int
    let batteryTypeNotificationPreferences: Int
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
    enum SpaceTarget {
        case existing(UUID)
        case create(name: String, roleHint: String, createdAt: Date)
    }

    enum SpaceImportMode {
        case preserveBackupSpaces
        case importIntoCurrentSpace(UUID)
        case map([UUID: SpaceTarget])
    }

    enum BackupImportError: Error {
        case unsupportedBackupFormatVersion(String)
        case unsupportedModelVersion(model: String, version: Int)
        case decodingFailed
        case duplicateModelID(model: String, id: UUID)
        case missingRequiredReference(model: String, field: String, id: UUID)
        case unresolvedReference(model: String, field: String, id: UUID)
    }

    private let supportedModelVersion = 1
    private let supportedFormatVersions: Set<String> = ["1", "1.0", "1.1", "1.2", "v1-1", "v1-2"]

    func importJSONData(
        _ data: Data,
        context: ModelContext,
        issueLogLinkedBatteryLogOverrides: [UUID: UUID?] = [:],
        spaceImportMode: SpaceImportMode = .preserveBackupSpaces
    ) throws -> BackupImportSummary {
        let envelope = try decodeAndValidateEnvelope(data)
        do {
            return try replaceAllData(
                with: envelope.models,
                spaces: envelope.spaces,
                context: context,
                issueLogLinkedBatteryLogOverrides: issueLogLinkedBatteryLogOverrides,
                spaceImportMode: spaceImportMode
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    func previewSpaces(in data: Data) throws -> [SpaceDTO_v1] {
        let envelope = try decodeAndValidateEnvelope(data)
        return normalizedBackupSpaces(spaces: envelope.spaces, models: envelope.models)
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
        try validateModelVersion(
            models.batteryTypeNotificationPreferences.version,
            model: "batteryTypeNotificationPreferences"
        )
    }

    private func replaceAllData(
        with models: BackupModels_v1,
        spaces: [SpaceDTO_v1],
        context: ModelContext,
        issueLogLinkedBatteryLogOverrides: [UUID: UUID?],
        spaceImportMode: SpaceImportMode
    ) throws -> BackupImportSummary {
        let _ = SpaceService.currentSpaceId(context: context)
        let normalizedSpaces = normalizedBackupSpaces(spaces: spaces, models: models)
        let spaceResolution = try resolveSpaces(
            mode: spaceImportMode,
            backupSpaces: normalizedSpaces,
            context: context
        )

        let currentLogs = try context.fetch(FetchDescriptor<BatteryLog>())
        let currentIssues = try context.fetch(FetchDescriptor<IssueLog>())
        let currentPacks = try context.fetch(FetchDescriptor<BatteryPack>())
        let currentNotifications = try context.fetch(FetchDescriptor<NotificationModel>())
        let currentBatteryTypeNotificationPreferences = try context.fetch(
            FetchDescriptor<BatteryTypeNotificationPreference>()
        )
        let currentAids = try context.fetch(FetchDescriptor<HearingAid>())

        for item in currentLogs { context.delete(item) }
        for item in currentIssues { context.delete(item) }
        for item in currentPacks { context.delete(item) }
        for item in currentNotifications { context.delete(item) }
        for item in currentBatteryTypeNotificationPreferences { context.delete(item) }
        for item in currentAids { context.delete(item) }

        let aidsById = try makeDictionary(items: models.hearingAids.items, modelName: "hearingAids") { dto in
            let resolvedSpaceId = resolvedSpaceId(
                candidate: dto.spaceId,
                mappedSpaceIds: spaceResolution.mappedSpaceIds,
                validSpaceIds: spaceResolution.validSpaceIds,
                fallbackSpaceId: spaceResolution.fallbackSpaceId
            )
            let aid = HearingAid(
                spaceId: resolvedSpaceId,
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
            let resolvedSpaceId = resolvedSpaceId(
                candidate: dto.spaceId,
                mappedSpaceIds: spaceResolution.mappedSpaceIds,
                validSpaceIds: spaceResolution.validSpaceIds,
                fallbackSpaceId: spaceResolution.fallbackSpaceId
            )
            let pack = BatteryPack(
                spaceId: resolvedSpaceId,
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
            let isMarkedLost = dto.isMarkedLost ?? false
            pack.isDone = (dto.isDone ?? false) || isMarkedLost
            pack.isMarkedLost = isMarkedLost
            pack.retailer = dto.retailer
            pack.note = dto.note
            if let dtoLots = dto.lots, dtoLots.isEmpty == false {
                pack.lots = dtoLots.sorted(by: { $0.sortIndex < $1.sortIndex }).map { lotDTO in
                    let lot = BatteryPackLot(
                        sortIndex: lotDTO.sortIndex,
                        quantityInitial: lotDTO.quantityInitial,
                        quantityRemaining: lotDTO.quantityRemaining,
                        openedAt: lotDTO.openedAt,
                        isMarkedLost: lotDTO.isMarkedLost,
                        note: lotDTO.note
                    )
                    lot.id = lotDTO.id
                    lot.createdAt = lotDTO.createdAt
                    return lot
                }
                pack.syncTotalsFromLots()
            } else {
                // Backward compatibility: old backups had no lots, so rebuild from aggregate fields.
                pack.ensureLotsIfNeeded()
            }
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
            let resolvedSpaceId = resolvedSpaceId(
                candidate: dto.spaceId,
                mappedSpaceIds: spaceResolution.mappedSpaceIds,
                validSpaceIds: spaceResolution.validSpaceIds,
                fallbackSpaceId: spaceResolution.fallbackSpaceId
            )

            let log = BatteryLog(
                spaceId: resolvedSpaceId,
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
            let isResolved = dto.isResolved ?? false
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
            let resolvedSpaceId = resolvedSpaceId(
                candidate: dto.spaceId,
                mappedSpaceIds: spaceResolution.mappedSpaceIds,
                validSpaceIds: spaceResolution.validSpaceIds,
                fallbackSpaceId: spaceResolution.fallbackSpaceId
            )
            let issue = IssueLog(
                spaceId: resolvedSpaceId,
                hearingAid: aid,
                timestamp: dto.timestamp,
                issue: dto.issue,
                severity: dto.severity,
                note: dto.note,
                isResolved: isResolved,
                resolvedAt: isResolved ? dto.resolvedAt : nil,
                resolutionNote: isResolved ? dto.resolutionNote : nil
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
                morningMinute: dto.morningMinute,
                isLowBatteryPackWarningEnabled: dto.isLowBatteryPackWarningEnabled ?? true,
                lowBatteryPackThreshold: dto.lowBatteryPackThreshold ?? 4
            )
            notification.id = dto.id
            notification.createdAt = dto.createdAt
            context.insert(notification)
        }

        for dto in models.batteryTypeNotificationPreferences.items {
            let pref = BatteryTypeNotificationPreference(
                spaceId: dto.spaceId ?? Space.defaultSpaceId,
                batteryType: dto.batteryType,
                notificationsOn: dto.notificationsOn,
                sentFinal: dto.sentFinal
            )
            pref.id = dto.id
            pref.createdAt = dto.createdAt
            context.insert(pref)
        }

        try context.save()
        return BackupImportSummary(
            hearingAids: models.hearingAids.items.count,
            batteryLogs: models.batteryLogs.items.count,
            batteryPacks: models.batteryPacks.items.count,
            issueLogs: models.issueLogs.items.count,
            notifications: models.notifications.items.count,
            batteryTypeNotificationPreferences: models.batteryTypeNotificationPreferences.items.count
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
        guard version == supportedModelVersion else {
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

        let normalizedVersion = normalizeFormatVersion(envelope.backupFormatVersion)
        guard supportedFormatVersions.contains(normalizedVersion) else {
            throw BackupImportError.unsupportedBackupFormatVersion(envelope.backupFormatVersion)
        }

        try validateModelVersions(envelope.models)
        return envelope
    }

    private func normalizeFormatVersion(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func upsertSpaces(_ spaces: [SpaceDTO_v1], context: ModelContext) throws -> Space {
        let existingSpaces = try context.fetch(FetchDescriptor<Space>())
        var existingById: [UUID: Space] = Dictionary(uniqueKeysWithValues: existingSpaces.map { ($0.id, $0) })

        for dto in spaces {
            if let existing = existingById[dto.id] {
                existing.name = dto.name
                existing.roleHint = dto.roleHint
                existing.createdAt = dto.createdAt
            } else {
                let created = Space(
                    id: dto.id,
                    name: dto.name,
                    roleHint: dto.roleHint,
                    createdAt: dto.createdAt
                )
                context.insert(created)
                existingById[created.id] = created
            }
        }

        if let defaultSpace = existingById[Space.defaultSpaceId] {
            return defaultSpace
        }

        let createdDefault = Space.makeDefaultSpace()
        context.insert(createdDefault)
        return createdDefault
    }

    private func normalizedBackupSpaces(spaces: [SpaceDTO_v1], models: BackupModels_v1) -> [SpaceDTO_v1] {
        var normalized = spaces
        var knownIds = Set(spaces.map(\.id))

        let candidateIds = Set(
            models.hearingAids.items.compactMap(\.spaceId) +
            models.batteryLogs.items.compactMap(\.spaceId) +
            models.batteryPacks.items.compactMap(\.spaceId) +
            models.issueLogs.items.compactMap(\.spaceId)
        )

        for id in candidateIds where knownIds.contains(id) == false {
            normalized.append(
                SpaceDTO_v1(
                    id: id,
                    name: "Imported Space",
                    roleHint: "other",
                    createdAt: Date()
                )
            )
            knownIds.insert(id)
        }

        if normalized.isEmpty {
            normalized.append(
                SpaceDTO_v1(
                    id: Space.defaultSpaceId,
                    name: "Personal",
                    roleHint: "self",
                    createdAt: Date()
                )
            )
        }

        return normalized.sorted { $0.createdAt < $1.createdAt }
    }

    private struct SpaceResolution {
        let mappedSpaceIds: [UUID: UUID]
        let validSpaceIds: Set<UUID>
        let fallbackSpaceId: UUID
    }

    private func resolveSpaces(
        mode: SpaceImportMode,
        backupSpaces: [SpaceDTO_v1],
        context: ModelContext
    ) throws -> SpaceResolution {
        let defaultCreatedAt = backupSpaces.first(where: { $0.id == Space.defaultSpaceId })?.createdAt ?? Date()

        switch mode {
        case .preserveBackupSpaces:
            let defaultSpace = try upsertSpaces(backupSpaces, context: context)
            let allSpaces = try context.fetch(FetchDescriptor<Space>())
            let validSpaceIds = Set(allSpaces.map(\.id))
            var mappedSpaceIds: [UUID: UUID] = [:]
            for space in backupSpaces {
                mappedSpaceIds[space.id] = space.id
            }
            return SpaceResolution(
                mappedSpaceIds: mappedSpaceIds,
                validSpaceIds: validSpaceIds,
                fallbackSpaceId: defaultSpace.id
            )

        case .importIntoCurrentSpace(let currentSpaceId):
            let existingSpaces = try context.fetch(FetchDescriptor<Space>())
            if existingSpaces.contains(where: { $0.id == currentSpaceId }) == false {
                let created = Space(
                    id: currentSpaceId,
                    name: "Personal",
                    roleHint: "self",
                    createdAt: defaultCreatedAt
                )
                context.insert(created)
            }
            let allSpaces = try context.fetch(FetchDescriptor<Space>())
            let validSpaceIds = Set(allSpaces.map(\.id))
            var mappedSpaceIds: [UUID: UUID] = [:]
            for space in backupSpaces {
                mappedSpaceIds[space.id] = currentSpaceId
            }
            return SpaceResolution(
                mappedSpaceIds: mappedSpaceIds,
                validSpaceIds: validSpaceIds,
                fallbackSpaceId: currentSpaceId
            )

        case .map(let mapping):
            let existingSpaces = try context.fetch(FetchDescriptor<Space>())
            var existingById = Dictionary(uniqueKeysWithValues: existingSpaces.map { ($0.id, $0) })
            var mappedSpaceIds: [UUID: UUID] = [:]
            mappedSpaceIds.reserveCapacity(backupSpaces.count)

            for source in backupSpaces {
                let target = mapping[source.id] ?? .create(
                    name: source.name,
                    roleHint: source.roleHint,
                    createdAt: source.createdAt
                )

                switch target {
                case .existing(let id):
                    if existingById[id] == nil {
                        let created = Space(
                            id: id,
                            name: source.name,
                            roleHint: source.roleHint,
                            createdAt: source.createdAt
                        )
                        context.insert(created)
                        existingById[id] = created
                    }
                    mappedSpaceIds[source.id] = id

                case .create(let name, let roleHint, let createdAt):
                    let created = Space(name: name, roleHint: roleHint, createdAt: createdAt)
                    context.insert(created)
                    existingById[created.id] = created
                    mappedSpaceIds[source.id] = created.id
                }
            }

            if existingById[Space.defaultSpaceId] == nil {
                let createdDefault = Space.makeDefaultSpace()
                context.insert(createdDefault)
                existingById[createdDefault.id] = createdDefault
            }

            let fallbackSpaceId = mappedSpaceIds[Space.defaultSpaceId]
                ?? mappedSpaceIds.values.first
                ?? Space.defaultSpaceId

            return SpaceResolution(
                mappedSpaceIds: mappedSpaceIds,
                validSpaceIds: Set(existingById.keys),
                fallbackSpaceId: fallbackSpaceId
            )
        }
    }

    private func resolvedSpaceId(
        candidate: UUID?,
        mappedSpaceIds: [UUID: UUID],
        validSpaceIds: Set<UUID>,
        fallbackSpaceId: UUID
    ) -> UUID {
        if let candidate, let mapped = mappedSpaceIds[candidate], validSpaceIds.contains(mapped) {
            return mapped
        }
        guard let candidate, validSpaceIds.contains(candidate) else {
            return fallbackSpaceId
        }
        return candidate
    }
}

private protocol HasID {
    var id: UUID { get }
}

extension HearingAidDTO_v1: HasID {}
extension BatteryLogDTO_v1: HasID {}
extension BatteryPackDTO_v1: HasID {}
