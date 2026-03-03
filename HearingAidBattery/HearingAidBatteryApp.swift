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
    @StateObject private var activeSpaceSelection = ActiveSpaceSelectionService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Space.self,
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

            SpaceMigrationService.runIfNeeded(container: container)
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
                SpaceMigrationService.runIfNeeded(container: retryContainer)
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
            AppRootView()
                .environmentObject(activeSpaceSelection)
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var activeSpaceSelection: ActiveSpaceSelectionService

    var body: some View {
        ContentView()
            .appBackground()
            .onAppear {
                activeSpaceSelection.bootstrap(context: context)
            }
    }
}
