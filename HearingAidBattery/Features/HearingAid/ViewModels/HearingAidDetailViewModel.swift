//
//  HearingAidDetailViewModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class HearingAidDetailViewModel: ObservableObject {
    @Published var isEditing: Bool = false
    @Published var editName: String = ""
    @Published var editModel: String = ""
    @Published var editBatteryType: String = ""
    @Published var editRetired: Bool = false
    @Published var showsDeleteAlert: Bool = false
    @Published var showsLogSheet: Bool = false
    @Published var logNote: String = ""
    @Published var logTimestamp: Date = Date()
    @Published var showsInventoryWarning: Bool = false
    @Published var selectedPackId: UUID?

    private let hearingAidService: HearingAidService
    private let batteryLogService: BatteryLogProviding

    init(hearingAidService: HearingAidService, batteryLogService: BatteryLogProviding) {
        self.hearingAidService = hearingAidService
        self.batteryLogService = batteryLogService
    }

    convenience init() {
        self.init(hearingAidService: HearingAidService(), batteryLogService: BatteryLogService())
    }

    func syncFromAid(_ hearingAid: HearingAid) {
        guard !isEditing else { return }
        editName = hearingAid.name
        editModel = hearingAid.model ?? ""
        editBatteryType = hearingAid.batteryType ?? ""
        editRetired = hearingAid.retired
    }

    func beginEditing(with hearingAid: HearingAid) {
        editName = hearingAid.name
        editModel = hearingAid.model ?? ""
        editBatteryType = hearingAid.batteryType ?? ""
        editRetired = hearingAid.retired
        isEditing = true
    }

    func endEditing(resetWith hearingAid: HearingAid, reset: Bool) {
        if reset {
            editName = hearingAid.name
            editModel = hearingAid.model ?? ""
            editBatteryType = hearingAid.batteryType ?? ""
            editRetired = hearingAid.retired
        }

        isEditing = false
    }

    func saveEdits(for hearingAid: HearingAid, context: ModelContext) {
        try? hearingAidService.updateHearingAid(
            hearingAid,
            name: editName,
            model: editModel,
            batteryType: editBatteryType,
            retired: editRetired,
            context: context
        )
        endEditing(resetWith: hearingAid, reset: true)
    }

    func deleteHearingAid(_ hearingAid: HearingAid, context: ModelContext) {
        try? hearingAidService.deleteHearingAid(hearingAid, context: context)
    }

    func updateLog(
        _ log: BatteryLog,
        timestamp: Date,
        note: String?,
        excludeFromStats: Bool,
        excludePreviousGapFromStats: Bool,
        context: ModelContext
    ) {
        try? batteryLogService.updateLog(
            log,
            timestamp: timestamp,
            note: note,
            excludeFromStats: excludeFromStats,
            excludePreviousGapFromStats: excludePreviousGapFromStats,
            context: context
        )
    }

    func deleteLog(_ log: BatteryLog, context: ModelContext) {
        try? batteryLogService.deleteLog(log, context: context)
    }

    func deleteLogs(at offsets: IndexSet, logs: [BatteryLog], context: ModelContext) {
        try? batteryLogService.deleteLogs(at: offsets, from: logs, context: context)
    }

    func beginLog() {
        logNote = ""
        logTimestamp = Date()
        selectedPackId = nil
        showsLogSheet = true
    }

    func endLog() {
        logNote = ""
        logTimestamp = Date()
        selectedPackId = nil
        showsLogSheet = false
    }

    func saveLog(for hearingAid: HearingAid, timestamp: Date, note: String?, context: ModelContext) {
        let consumedPack = (try? batteryLogService.quickLog(
            for: hearingAid,
            timestamp: timestamp,
            note: note,
            selectedPackId: selectedPackId,
            context: context
        )) ?? true
        showsInventoryWarning = !consumedPack
        endLog()
    }

    func dismissInventoryWarning() {
        showsInventoryWarning = false
    }
}
