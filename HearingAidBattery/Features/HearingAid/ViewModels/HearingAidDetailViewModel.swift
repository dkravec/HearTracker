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
    @Published var errorMessage: String?

    private let hearingAidService: HearingAidService
    private let batteryLogService: BatteryLogProviding
    private let notificationService: NotificationService

    init(
        hearingAidService: HearingAidService,
        batteryLogService: BatteryLogProviding,
        notificationService: NotificationService
    ) {
        self.hearingAidService = hearingAidService
        self.batteryLogService = batteryLogService
        self.notificationService = notificationService
    }

    convenience init() {
        self.init(
            hearingAidService: HearingAidService(),
            batteryLogService: BatteryLogService(),
            notificationService: NotificationService()
        )
    }

    func syncFromAid(_ hearingAid: HearingAid) {
        guard !isEditing else { return }
        editName = hearingAid.name
        editModel = hearingAid.model ?? ""
        editBatteryType = hearingAid.batteryType ?? ""
        editRetired = hearingAid.retired
    }

    func beginEditing(with hearingAid: HearingAid) {
        errorMessage = nil
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
        do {
            try hearingAidService.updateHearingAid(
                hearingAid,
                name: editName,
                model: editModel,
                batteryType: editBatteryType,
                retired: editRetired,
                context: context
            )
            errorMessage = nil
            endEditing(resetWith: hearingAid, reset: true)
        } catch {
            errorMessage = "Could not save hearing aid changes."
        }
    }

    func deleteHearingAid(_ hearingAid: HearingAid, context: ModelContext) -> Bool {
        do {
            try hearingAidService.deleteHearingAid(hearingAid, context: context)
            return true
        } catch {
            errorMessage = "Could not delete hearing aid."
            return false
        }
    }

    func updateLog(
        _ log: BatteryLog,
        timestamp: Date,
        note: String?,
        excludeFromStats: Bool,
        excludePreviousGapFromStats: Bool,
        context: ModelContext
    ) {
        let hearingAidId = log.hearingAid?.id
        do {
            try batteryLogService.updateLog(
                log,
                timestamp: timestamp,
                note: note,
                excludeFromStats: excludeFromStats,
                excludePreviousGapFromStats: excludePreviousGapFromStats,
                context: context
            )
            if let hearingAidId {
                Task {
                    await notificationService.rescheduleNotifications(for: hearingAidId, context: context)
                }
            }
        } catch {
            errorMessage = "Could not update battery log."
        }
    }

    func deleteLog(_ log: BatteryLog, context: ModelContext) {
        let hearingAidId = log.hearingAid?.id
        do {
            try batteryLogService.deleteLog(log, context: context)
            if let hearingAidId {
                Task {
                    await notificationService.rescheduleNotifications(for: hearingAidId, context: context)
                }
            }
        } catch {
            errorMessage = "Could not delete battery log."
        }
    }

    func deleteLogs(at offsets: IndexSet, logs: [BatteryLog], context: ModelContext) {
        let hearingAidId = offsets.compactMap { logs[$0].hearingAid?.id }.first
        do {
            try batteryLogService.deleteLogs(at: offsets, from: logs, context: context)
            if let hearingAidId {
                Task {
                    await notificationService.rescheduleNotifications(for: hearingAidId, context: context)
                }
            }
        } catch {
            errorMessage = "Could not delete selected battery logs."
        }
    }

    func beginLog() {
        errorMessage = nil
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
        do {
            let consumedPack = try batteryLogService.quickLog(
                for: hearingAid,
                timestamp: timestamp,
                note: note,
                selectedPackId: selectedPackId,
                context: context
            )
            errorMessage = nil
            showsInventoryWarning = !consumedPack
            Task {
                await notificationService.rescheduleNotifications(for: hearingAid.id, context: context)
            }
            endLog()
        } catch {
            errorMessage = "Could not save battery log."
        }
    }

    func dismissInventoryWarning() {
        showsInventoryWarning = false
    }

    func excludeFromAverages(_ log: BatteryLog, hearingAidId: UUID, context: ModelContext) {
        guard log.excludeFromStats == false else { return }
        log.excludeFromStats = true
        try? context.save()
        Task {
            await notificationService.rescheduleNotifications(for: hearingAidId, context: context)
        }
    }
}
