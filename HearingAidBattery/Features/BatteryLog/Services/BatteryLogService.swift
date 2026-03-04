//
//  BatteryLogService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import Foundation
import SwiftData

@MainActor
protocol BatteryLogProviding {
    func quickLog(
        for hearingAid: HearingAid,
        timestamp: Date,
        note: String?,
        selectedPackId: UUID?,
        context: ModelContext
    ) throws -> Bool
    func updateLog(
        _ log: BatteryLog,
        timestamp: Date,
        note: String?,
        excludeFromStats: Bool,
        excludePreviousGapFromStats: Bool,
        context: ModelContext
    ) throws
    func deleteLog(_ log: BatteryLog, context: ModelContext) throws
    func deleteLogs(at offsets: IndexSet, from logs: [BatteryLog], context: ModelContext) throws
}

@MainActor
final class BatteryLogService: BatteryLogProviding {
    private let batteryPackService = BatteryPackService()

    func quickLog(
        for hearingAid: HearingAid,
        timestamp: Date = Date(),
        note: String? = nil,
        selectedPackId: UUID? = nil,
        context: ModelContext
    ) throws -> Bool {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = (trimmedNote?.isEmpty == true) ? nil : trimmedNote
        let previousType = mostRecentLoggedBatteryType(
            for: hearingAid.id,
            spaceId: hearingAid.spaceId,
            context: context
        )
            ?? hearingAid.batteryType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let consumedPack = batteryPackService.consumeOneBattery(
            selectedPackId: selectedPackId,
            preferredBatteryType: selectedPackId == nil ? previousType : nil,
            spaceId: hearingAid.spaceId,
            context: context
        )

        let newLog = BatteryLog(
            spaceId: hearingAid.spaceId,
            hearingAid: hearingAid,
            timestamp: timestamp,
            note: normalizedNote
        )
        newLog.batteryPack = consumedPack
        newLog.batteryType = consumedPack?.batteryType ?? previousType

        context.insert(newLog)
        try context.save()
        return consumedPack != nil
    }

    func updateLog(
        _ log: BatteryLog,
        timestamp: Date,
        note: String?,
        excludeFromStats: Bool,
        excludePreviousGapFromStats: Bool,
        context: ModelContext
    ) throws {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = (trimmedNote?.isEmpty == true) ? nil : trimmedNote

        log.timestamp = timestamp
        log.note = normalizedNote
        log.excludeFromStats = excludeFromStats
        log.excludePreviousGapFromStats = excludePreviousGapFromStats

        try context.save()
    }

    func deleteLog(_ log: BatteryLog, context: ModelContext) throws {
        restoreBatteryIfNeeded(for: log)
        context.delete(log)
        try context.save()
    }

    func deleteLogs(at offsets: IndexSet, from logs: [BatteryLog], context: ModelContext) throws {
        var restoreCountsByPackId: [UUID: (pack: BatteryPack, count: Int)] = [:]
        for index in offsets {
            let log = logs[index]
            if let pack = log.batteryPack {
                restoreCountsByPackId[pack.id, default: (pack: pack, count: 0)].count += 1
            }
        }

        for entry in restoreCountsByPackId.values {
            restoreBatteries(count: entry.count, in: entry.pack)
        }

        for index in offsets {
            context.delete(logs[index])
        }

        try context.save()
    }

    private func mostRecentLoggedBatteryType(for hearingAidId: UUID, spaceId: UUID, context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<BatteryLog>(
            predicate: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId && $0.spaceId == spaceId },
            sortBy: [SortDescriptor(\BatteryLog.timestamp, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.first(where: { ($0.batteryType?.isEmpty == false) })?.batteryType
    }

    private func restoreBatteryIfNeeded(for log: BatteryLog) {
        guard let pack = log.batteryPack else { return }
        restoreBatteries(count: 1, in: pack)
    }

    private func restoreBatteries(count: Int, in pack: BatteryPack) {
        guard count > 0 else { return }
        let restoredQuantity = min(pack.quantityPurchased, pack.quantityRemaining + count)
        pack.quantityRemaining = max(0, restoredQuantity)
    }
}
