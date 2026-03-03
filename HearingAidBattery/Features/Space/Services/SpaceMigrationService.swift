//
//  SpaceMigrationService.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-03.
//

import Foundation
import SwiftData

enum SpaceMigrationService {
    static func runIfNeeded(container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaultSpace = try ensureDefaultSpace(in: context)
        try backfillRecords(in: context, defaultSpaceId: defaultSpace.id)

        if context.hasChanges {
            try context.save()
        }
    }

    @discardableResult
    private static func ensureDefaultSpace(in context: ModelContext) throws -> Space {
        let defaultSpaceId = Space.defaultSpaceId
        let descriptor = FetchDescriptor<Space>(
            predicate: #Predicate { $0.id == defaultSpaceId },
            sortBy: []
        )

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let name = defaultSpaceName()
        let created = Space.makeDefaultSpace(name: name, roleHint: "self")
        context.insert(created)
        return created
    }

    private static func backfillRecords(in context: ModelContext, defaultSpaceId: UUID) throws {
        let spaces = try context.fetch(FetchDescriptor<Space>())
        let validSpaceIds = Set(spaces.map(\.id))

        let hearingAids = try context.fetch(FetchDescriptor<HearingAid>())
        for hearingAid in hearingAids where validSpaceIds.contains(hearingAid.spaceId) == false {
            hearingAid.spaceId = defaultSpaceId
        }

        let batteryLogs = try context.fetch(FetchDescriptor<BatteryLog>())
        for log in batteryLogs where validSpaceIds.contains(log.spaceId) == false {
            log.spaceId = defaultSpaceId
        }

        let batteryPacks = try context.fetch(FetchDescriptor<BatteryPack>())
        for pack in batteryPacks where validSpaceIds.contains(pack.spaceId) == false {
            pack.spaceId = defaultSpaceId
        }

        let issues = try context.fetch(FetchDescriptor<IssueLog>())
        for issue in issues where validSpaceIds.contains(issue.spaceId) == false {
            issue.spaceId = defaultSpaceId
        }
    }

    private static func defaultSpaceName() -> String {
        let defaults = UserDefaults.standard
        let keys = ["displayName", "userDisplayName", "onboardingDisplayName"]

        for key in keys {
            if let candidate = defaults.string(forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               candidate.isEmpty == false {
                return candidate
            }
        }

        return "Personal"
    }
}
