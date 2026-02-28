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
    let backupFormatVersion: Int
    let exportedAt: Date
    let models: BackupModels_v1
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
