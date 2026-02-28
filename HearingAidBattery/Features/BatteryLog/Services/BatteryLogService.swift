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
    func quickLog(for hearingAid: HearingAid, timestamp: Date, note: String?, context: ModelContext) throws -> Bool
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
        context: ModelContext
    ) throws -> Bool {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = (trimmedNote?.isEmpty == true) ? nil : trimmedNote
        let didConsumePack = batteryPackService.consumeOneBatteryFIFO(for: hearingAid.id, context: context)

        let newLog = BatteryLog(
            hearingAid: hearingAid,
            timestamp: timestamp,
            note: normalizedNote
        )

        context.insert(newLog)
        try context.save()
        return didConsumePack
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
        context.delete(log)
        try context.save()
    }

    func deleteLogs(at offsets: IndexSet, from logs: [BatteryLog], context: ModelContext) throws {
        for index in offsets {
            context.delete(logs[index])
        }

        try context.save()
    }
}
