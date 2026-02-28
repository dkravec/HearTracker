import Foundation

enum NotesImportItemKind: String, Codable {
    case battery
    case issue
}

struct NotesImportParsedItem: Identifiable, Hashable {
    let id: UUID
    let kind: NotesImportItemKind
    let originalLine: String
    let timestamp: Date?
    let parsedLine: String?
    let timestampInferred: Bool

    init(
        id: UUID = UUID(),
        kind: NotesImportItemKind,
        originalLine: String,
        timestamp: Date?,
        parsedLine: String?,
        timestampInferred: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.originalLine = originalLine
        self.timestamp = timestamp
        self.parsedLine = parsedLine
        self.timestampInferred = timestampInferred
    }
}

struct NotesImportParseResult {
    let batteryEvents: [NotesImportParsedItem]
    let issues: [NotesImportParsedItem]
    let unknownLines: [String]
    let warnings: [String]

    var allItems: [NotesImportParsedItem] {
        batteryEvents + issues
    }
}

struct NotesImportPreviewItem: Identifiable, Hashable {
    let id: UUID
    var kind: NotesImportItemKind
    let originalLine: String
    var note: String
    var resolvedTimestamp: Date?
    let timestampInferred: Bool

    init(parsed: NotesImportParsedItem) {
        self.id = parsed.id
        self.kind = parsed.kind
        self.originalLine = parsed.originalLine
        self.note = parsed.parsedLine ?? ""
        self.resolvedTimestamp = parsed.timestamp
        self.timestampInferred = parsed.timestampInferred
    }
}

struct NotesImportCommitResult {
    let createdBatteryLogs: Int
    let createdIssues: Int
    let skippedDuplicates: Int
    let unresolvedSkipped: Int
}
