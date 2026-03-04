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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var activeSpaceSelection: ActiveSpaceSelectionService
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false
    @AppStorage("onboarding.step") private var onboardingStepRaw: String = "name"
    @AppStorage("onboarding.spaceId") private var onboardingSpaceIdString: String = ""

    var body: some View {
        Group {
            if onboardingCompleted == false {
                OnboardingFlowView()
                    .id(activeSpaceSelection.activeSpaceId)
            } else {
                ContentView()
                    .id(activeSpaceSelection.activeSpaceId)
            }
        }
        .onAppear {
            activeSpaceSelection.bootstrap(context: context)
            reevaluateFlow()
        }
        .onChange(of: activeSpaceSelection.activeSpaceId) {
            reevaluateFlow()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                reevaluateFlow()
            }
        }
    }

    private func reevaluateFlow() {
        let currentSpaceId = SpaceService.currentSpaceId(context: context)
        if activeSpaceSelection.activeSpaceId != currentSpaceId {
            activeSpaceSelection.refresh(context: context)
        }

        // One-way auto-complete only for legacy/existing users who have
        // not started onboarding progress in this install.
        if onboardingCompleted == false,
           hasOnboardingProgress == false,
           hasAnyTrackedData() {
            onboardingCompleted = true
        }
    }

    private var hasOnboardingProgress: Bool {
        onboardingStepRaw != "name" || onboardingSpaceIdString.isEmpty == false
    }

    private func hasAnyTrackedData() -> Bool {
        var aidDescriptor = FetchDescriptor<HearingAid>()
        aidDescriptor.fetchLimit = 1
        if ((try? context.fetch(aidDescriptor)) ?? []).isEmpty == false {
            return true
        }

        var packDescriptor = FetchDescriptor<BatteryPack>()
        packDescriptor.fetchLimit = 1
        return ((try? context.fetch(packDescriptor)) ?? []).isEmpty == false
    }
}
