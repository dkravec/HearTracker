//
//  HearingAidBatteryApp.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct HearingAidBatteryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HearingAid.self,
            BatteryLog.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.net.novapro.HearingAidBattery")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
#if DEBUG
            print("ModelContainer load failed: \(error)")
            // If the local store is incompatible (e.g., after model changes), reset it in debug builds.
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            if let recovery = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                return recovery
            }

            // If CloudKit is causing the failure, fall back to local-only storage in debug.
            let localOnlyConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            if let localOnly = try? ModelContainer(for: schema, configurations: [localOnlyConfiguration]) {
                return localOnly
            }
#endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
