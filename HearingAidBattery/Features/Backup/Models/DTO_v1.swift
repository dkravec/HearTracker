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
}
