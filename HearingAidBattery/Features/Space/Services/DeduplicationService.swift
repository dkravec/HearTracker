//
//  DeduplicationService.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-05.
//

import Foundation
import SwiftData

/// Removes duplicate records that may have been created by iCloud sync conflicts.
/// Should run on app launch before any views load to prevent crashes from unique constraints.
@MainActor
struct DeduplicationService {

    /// Runs deduplication for all model types. Call this once on app startup.
    static func runIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)

        do {
            var totalRemoved = 0
            totalRemoved += try deduplicateHearingAids(context: context)
            totalRemoved += try deduplicateBatteryLogs(context: context)
            totalRemoved += try deduplicateBatteryPacks(context: context)
            totalRemoved += try deduplicateBatteryPackLots(context: context)
            totalRemoved += try deduplicateIssueLogs(context: context)
            totalRemoved += try deduplicateSpaces(context: context)
            totalRemoved += try deduplicateNotifications(context: context)
            totalRemoved += try deduplicateBatteryTypePreferences(context: context)

            if totalRemoved > 0 {
                try context.save()
                print("DeduplicationService: Removed \(totalRemoved) duplicate records")
            }
        } catch {
            print("DeduplicationService: Failed to deduplicate - \(error)")
            context.rollback()
        }
    }

    // MARK: - Private Deduplication Methods

    private static func deduplicateHearingAids(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<HearingAid>(sortBy: [SortDescriptor(\.createdAt)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateBatteryLogs(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<BatteryLog>(sortBy: [SortDescriptor(\.timestamp)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateBatteryPacks(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<BatteryPack>(sortBy: [SortDescriptor(\.createdAt)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateBatteryPackLots(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<BatteryPackLot>(sortBy: [SortDescriptor(\.createdAt)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateIssueLogs(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<IssueLog>(sortBy: [SortDescriptor(\.timestamp)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateSpaces(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<Space>(sortBy: [SortDescriptor(\.createdAt)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateNotifications(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<NotificationModel>(sortBy: [SortDescriptor(\.createdAt)]))
        return removeDuplicates(items: all, context: context)
    }

    private static func deduplicateBatteryTypePreferences(context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<BatteryTypeNotificationPreference>(sortBy: [SortDescriptor(\.createdAt)]))
        return removeDuplicates(items: all, context: context)
    }

    /// Generic deduplication: keeps first occurrence (by sort order), deletes subsequent duplicates.
    private static func removeDuplicates<T: PersistentModel & Identifiable>(
        items: [T],
        context: ModelContext
    ) -> Int where T.ID == UUID {
        var seen = Set<UUID>()
        var removedCount = 0

        for item in items {
            if seen.contains(item.id) {
                context.delete(item)
                removedCount += 1
            } else {
                seen.insert(item.id)
            }
        }

        return removedCount
    }
}
