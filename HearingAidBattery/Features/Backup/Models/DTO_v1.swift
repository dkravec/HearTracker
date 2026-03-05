import Foundation

struct HearingAidDTO_v1: Codable {
    let id: UUID
    let spaceId: UUID?
    let createdAt: Date
    let name: String
    let model: String?
    let batteryType: String?
    let retired: Bool
    let notificationsEnabled: Bool?
}

struct BatteryLogDTO_v1: Codable {
    let id: UUID
    let spaceId: UUID?
    let hearingAidId: UUID?
    let batteryPackId: UUID?
    let timestamp: Date
    let note: String?
    let excludeFromStats: Bool
    let excludePreviousGapFromStats: Bool
    let batteryType: String?
}

struct BatteryPackDTO_v1: Codable {
    let id: UUID
    let spaceId: UUID?
    let createdAt: Date
    let batteryType: String
    let purchaseDate: Date
    let batteriesPerPack: Int
    let numberOfPacks: Int
    let quantityPurchased: Int
    let quantityRemaining: Int
    let isDone: Bool?
    let isMarkedLost: Bool?
    let priceAmount: Decimal?
    let currencyCode: String?
    let brand: String?
    let retailer: String?
    let note: String?
    let lots: [BatteryPackLotDTO_v1]?
}

struct BatteryPackLotDTO_v1: Codable {
    let id: UUID
    let createdAt: Date
    let sortIndex: Int
    let openedAt: Date?
    let quantityInitial: Int
    let quantityRemaining: Int
    let isMarkedLost: Bool
    let note: String?
}

struct IssueLogDTO_v1: Codable {
    let id: UUID
    let spaceId: UUID?
    let hearingAidId: UUID?
    let timestamp: Date
    let issue: String
    let severity: Int?
    let note: String?
    let linkedBatteryLogId: UUID?
    let isResolved: Bool?
    let resolvedAt: Date?
    let resolutionNote: String?
}

struct SpaceDTO_v1: Codable {
    let id: UUID
    let name: String
    let roleHint: String
    let createdAt: Date
}

struct SettingsDTO_v1: Codable {
    let key: String
    let value: String
}

struct NotificationDTO_v1: Codable {
    let id: UUID
    let createdAt: Date
    let isEnabled: Bool
    let isExpectedDeathWarningEnabled: Bool?
    let expectedDeathWarningHours: Int?
    let expectedDeathWarningMinutes: Int?
    let isMorningHeadsUpEnabled: Bool?
    let morningHour: Int
    let morningMinute: Int
    let isLowBatteryPackWarningEnabled: Bool?
    let lowBatteryPackThreshold: Int?
}

struct BatteryTypeNotificationPreferenceDTO_v1: Codable {
    let id: UUID
    let createdAt: Date
    let spaceId: UUID?
    let batteryType: String
    let notificationsOn: Bool
    let sentFinal: Bool

    init(
        id: UUID,
        createdAt: Date,
        spaceId: UUID?,
        batteryType: String,
        notificationsOn: Bool,
        sentFinal: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.spaceId = spaceId
        self.batteryType = batteryType
        self.notificationsOn = notificationsOn
        self.sentFinal = sentFinal
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case spaceId
        case batteryType
        case notificationsOn
        case sentFinal
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        spaceId = try container.decodeIfPresent(UUID.self, forKey: .spaceId)
        batteryType = try container.decode(String.self, forKey: .batteryType)
        notificationsOn = try container.decode(Bool.self, forKey: .notificationsOn)
        sentFinal = try container.decode(Bool.self, forKey: .sentFinal)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(spaceId, forKey: .spaceId)
        try container.encode(batteryType, forKey: .batteryType)
        try container.encode(notificationsOn, forKey: .notificationsOn)
        try container.encode(sentFinal, forKey: .sentFinal)
    }
}
