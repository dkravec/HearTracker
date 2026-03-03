import Foundation
import SwiftData

@MainActor
struct BackupExportService {
    private let modelVersion = 1
    private let backupFormatVersion = "1.1"

    func exportJSONData(context: ModelContext) throws -> Data {
        let spaces = try context.fetch(FetchDescriptor<Space>())
        let hearingAids = try context.fetch(FetchDescriptor<HearingAid>())
        let batteryLogs = try context.fetch(FetchDescriptor<BatteryLog>())
        let batteryPacks = try context.fetch(FetchDescriptor<BatteryPack>())
        let issueLogs = try context.fetch(FetchDescriptor<IssueLog>())
        let notifications = try context.fetch(FetchDescriptor<NotificationModel>())

        let envelope = BackupEnvelope(
            backupFormatVersion: backupFormatVersion,
            exportedAt: Date(),
            spaces: spaces.map(dto),
            models: BackupModels_v1(
                hearingAids: ModelBlock(version: modelVersion, items: hearingAids.map(dto)),
                batteryLogs: ModelBlock(version: modelVersion, items: batteryLogs.map(dto)),
                batteryPacks: ModelBlock(version: modelVersion, items: batteryPacks.map(dto)),
                issueLogs: ModelBlock(version: modelVersion, items: issueLogs.map(dto)),
                settings: ModelBlock(version: modelVersion, items: []),
                notifications: ModelBlock(version: modelVersion, items: notifications.map(dto))
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
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
            note: batteryPack.note
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
            morningMinute: notification.morningMinute
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
