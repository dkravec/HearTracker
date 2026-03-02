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
            BatteryPack.self,
            IssueLog.self,
            NotificationModel.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.net.novapro.HearingAidBattery")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
#if DEBUG
            let configuredStoreURL = modelConfiguration.url.absoluteString
            let resolvedStoreURLs = container.configurations.map { $0.url.absoluteString }
            print("SwiftData configured store URL: \(configuredStoreURL)")
            print("SwiftData resolved store URLs: \(resolvedStoreURLs)")
#endif
            return container
        } catch {
#if DEBUG
            print("ModelContainer initialization failed: \(error)")

            // Retry once for transient startup failures without mutating or switching stores.
            if let retryContainer = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                return retryContainer
            }

            fatalError("Could not create ModelContainer. Automatic reset/fallback is disabled to avoid data loss. Error: \(error)")
#else
            fatalError("Could not create ModelContainer: \(error)")
#endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView().appBackground()
        }
        .modelContainer(sharedModelContainer)
    }
}
