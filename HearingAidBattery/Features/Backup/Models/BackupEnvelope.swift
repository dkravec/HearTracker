import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BackupModels_v1: Codable {
    let hearingAids: ModelBlock<HearingAidDTO_v1>
    let batteryLogs: ModelBlock<BatteryLogDTO_v1>
    let batteryPacks: ModelBlock<BatteryPackDTO_v1>
    let issueLogs: ModelBlock<IssueLogDTO_v1>
    let settings: ModelBlock<SettingsDTO_v1>
    let notifications: ModelBlock<NotificationDTO_v1>
}

struct BackupEnvelope: Codable {
    let backupFormatVersion: String
    let exportedAt: Date
    let spaces: [SpaceDTO_v1]
    let models: BackupModels_v1

    private enum CodingKeys: String, CodingKey {
        case backupFormatVersion
        case exportedAt
        case spaces
        case models
    }

    init(
        backupFormatVersion: String,
        exportedAt: Date,
        spaces: [SpaceDTO_v1] = [],
        models: BackupModels_v1
    ) {
        self.backupFormatVersion = backupFormatVersion
        self.exportedAt = exportedAt
        self.spaces = spaces
        self.models = models
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let versionString = try? container.decode(String.self, forKey: .backupFormatVersion) {
            backupFormatVersion = versionString
        } else if let versionInt = try? container.decode(Int.self, forKey: .backupFormatVersion) {
            backupFormatVersion = String(versionInt)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .backupFormatVersion,
                in: container,
                debugDescription: "Unsupported backup format version value"
            )
        }
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        spaces = try container.decodeIfPresent([SpaceDTO_v1].self, forKey: .spaces) ?? []
        models = try container.decode(BackupModels_v1.self, forKey: .models)
    }
}

struct BackupJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
