import Foundation
import SwiftData

@MainActor
struct BackupExportService {
    private let modelVersion = 1
    private let backupFormatVersion = "1.2"

    func exportJSONData(context: ModelContext) throws -> Data {
        let spaces = try context.fetch(FetchDescriptor<Space>())
        let hearingAids = try context.fetch(FetchDescriptor<HearingAid>())
        let batteryLogs = try context.fetch(FetchDescriptor<BatteryLog>())
        let batteryPacks = try context.fetch(FetchDescriptor<BatteryPack>())
        let issueLogs = try context.fetch(FetchDescriptor<IssueLog>())
        let notifications = try context.fetch(FetchDescriptor<NotificationModel>())
        let batteryTypeNotificationPreferences = try context.fetch(FetchDescriptor<BatteryTypeNotificationPreference>())

        // Deduplicate by ID (keep first occurrence) to handle iCloud sync conflicts
        let uniqueHearingAids = deduplicateById(hearingAids)
        let uniqueBatteryLogs = deduplicateById(batteryLogs)
        let uniqueBatteryPacks = deduplicateById(batteryPacks)
        let uniqueIssueLogs = deduplicateById(issueLogs)
        let uniqueSpaces = deduplicateById(spaces)

        let envelope = BackupEnvelope(
            backupFormatVersion: backupFormatVersion,
            exportedAt: Date(),
            spaces: uniqueSpaces.map(dto),
            models: BackupModels_v1(
                hearingAids: ModelBlock(version: modelVersion, items: uniqueHearingAids.map(dto)),
                batteryLogs: ModelBlock(version: modelVersion, items: uniqueBatteryLogs.map(dto)),
                batteryPacks: ModelBlock(version: modelVersion, items: uniqueBatteryPacks.map(dto)),
                issueLogs: ModelBlock(version: modelVersion, items: uniqueIssueLogs.map(dto)),
                settings: ModelBlock(version: modelVersion, items: []),
                notifications: ModelBlock(version: modelVersion, items: notifications.map(dto)),
                batteryTypeNotificationPreferences: ModelBlock(
                    version: modelVersion,
                    items: batteryTypeNotificationPreferences.map(dto)
                )
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    /// Removes duplicate items by ID, keeping the first occurrence.
    private func deduplicateById<T: Identifiable>(_ items: [T]) -> [T] where T.ID == UUID {
        var seen = Set<UUID>()
        return items.filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }
    }

    private func dto(_ hearingAid: HearingAid) -> HearingAidDTO_v1 {
        HearingAidDTO_v1(
            id: hearingAid.id,
            spaceId: hearingAid.spaceId,
            createdAt: hearingAid.createdAt,
            name: hearingAid.name,
            model: hearingAid.model,
            batteryType: hearingAid.batteryType,
            retired: hearingAid.retired,
            notificationsEnabled: hearingAid.notificationsEnabled
        )
    }

    private func dto(_ batteryLog: BatteryLog) -> BatteryLogDTO_v1 {
        BatteryLogDTO_v1(
            id: batteryLog.id,
            spaceId: batteryLog.spaceId,
            hearingAidId: batteryLog.hearingAid?.id,
            batteryPackId: batteryLog.batteryPack?.id,
            timestamp: batteryLog.timestamp,
            note: batteryLog.note,
            excludeFromStats: batteryLog.excludeFromStats,
            excludePreviousGapFromStats: batteryLog.excludePreviousGapFromStats,
            batteryType: batteryLog.batteryType
        )
    }

    private func dto(_ batteryPack: BatteryPack) -> BatteryPackDTO_v1 {
        BatteryPackDTO_v1(
            id: batteryPack.id,
            spaceId: batteryPack.spaceId,
            createdAt: batteryPack.createdAt,
            batteryType: batteryPack.batteryType,
            purchaseDate: batteryPack.purchaseDate,
            batteriesPerPack: batteryPack.batteriesPerPack,
            numberOfPacks: batteryPack.numberOfPacks,
            quantityPurchased: batteryPack.quantityPurchased,
            quantityRemaining: batteryPack.quantityRemaining,
            isDone: batteryPack.isDone,
            isMarkedLost: batteryPack.isMarkedLost,
            priceAmount: batteryPack.priceAmount,
            currencyCode: batteryPack.currencyCode,
            brand: batteryPack.brand,
            retailer: batteryPack.retailer,
            note: batteryPack.note,
            lots: (batteryPack.lots ?? [])
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(dto)
        )
    }

    private func dto(_ lot: BatteryPackLot) -> BatteryPackLotDTO_v1 {
        BatteryPackLotDTO_v1(
            id: lot.id,
            createdAt: lot.createdAt,
            sortIndex: lot.sortIndex,
            openedAt: lot.openedAt,
            quantityInitial: lot.quantityInitial,
            quantityRemaining: lot.quantityRemaining,
            isMarkedLost: lot.isMarkedLost,
            note: lot.note
        )
    }

    private func dto(_ issueLog: IssueLog) -> IssueLogDTO_v1 {
        IssueLogDTO_v1(
            id: issueLog.id,
            spaceId: issueLog.spaceId,
            hearingAidId: issueLog.hearingAid?.id,
            timestamp: issueLog.timestamp,
            issue: issueLog.issue,
            severity: issueLog.severity,
            note: issueLog.note,
            linkedBatteryLogId: issueLog.linkedBatteryLogId,
            isResolved: issueLog.isResolved,
            resolvedAt: issueLog.resolvedAt,
            resolutionNote: issueLog.resolutionNote
        )
    }

    private func dto(_ notification: NotificationModel) -> NotificationDTO_v1 {
        NotificationDTO_v1(
            id: notification.id,
            createdAt: notification.createdAt,
            isEnabled: notification.isEnabled,
            isExpectedDeathWarningEnabled: notification.isExpectedDeathWarningEnabled,
            expectedDeathWarningHours: notification.expectedDeathWarningHours,
            expectedDeathWarningMinutes: notification.expectedDeathWarningMinutes,
            isMorningHeadsUpEnabled: notification.isMorningHeadsUpEnabled,
            morningHour: notification.morningHour,
            morningMinute: notification.morningMinute,
            isLowBatteryPackWarningEnabled: notification.isLowBatteryPackWarningEnabled,
            lowBatteryPackThreshold: notification.lowBatteryPackThreshold
        )
    }

    private func dto(_ pref: BatteryTypeNotificationPreference) -> BatteryTypeNotificationPreferenceDTO_v1 {
        BatteryTypeNotificationPreferenceDTO_v1(
            id: pref.id,
            createdAt: pref.createdAt,
            spaceId: pref.spaceId,
            batteryType: pref.batteryType,
            notificationsOn: pref.notificationsOn,
            sentFinal: pref.sentFinal
        )
    }

    private func dto(_ space: Space) -> SpaceDTO_v1 {
        SpaceDTO_v1(
            id: space.id,
            name: space.name,
            roleHint: space.roleHint,
            createdAt: space.createdAt
        )
    }
}
