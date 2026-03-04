//
//  HearingAidListViewModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class HearingAidListViewModel: ObservableObject {
    @Published var showsLogSheet: Bool = false
    @Published var selectedLogAidId: UUID?
    @Published var logNote: String = ""
    @Published var logTimestamp: Date = Date()
    @Published var showsInventoryWarning: Bool = false
    @Published var selectedPackId: UUID?
    @Published var selectedLotId: UUID?
    @Published var errorMessage: String?

    private let hearingAidService: HearingAidService
    private let batteryLogService: BatteryLogProviding
    private let statsService: BatteryStatsService
    private let notificationService: NotificationService

    init(
        hearingAidService: HearingAidService,
        batteryLogService: BatteryLogProviding,
        statsService: BatteryStatsService,
        notificationService: NotificationService
    ) {
        self.hearingAidService = hearingAidService
        self.batteryLogService = batteryLogService
        self.statsService = statsService
        self.notificationService = notificationService
    }

    convenience init() {
        self.init(
            hearingAidService: HearingAidService(),
            batteryLogService: BatteryLogService(),
            statsService: BatteryStatsService(),
            notificationService: NotificationService()
        )
    }

    func activeAids(from hearingAids: [HearingAid]) -> [HearingAid] {
        hearingAidService.activeAids(from: hearingAids)
    }

    func retiredAids(from hearingAids: [HearingAid]) -> [HearingAid] {
        hearingAidService.retiredAids(from: hearingAids)
    }

    /// Opens the log sheet pre-selecting the given hearing aid.
    func beginLog(for hearingAid: HearingAid) {
        errorMessage = nil
        logNote = ""
        logTimestamp = Date()
        selectedPackId = nil
        selectedLotId = nil
        selectedLogAidId = hearingAid.id
        showsLogSheet = true
    }

    func endLog() {
        logNote = ""
        logTimestamp = Date()
        selectedPackId = nil
        selectedLotId = nil
        selectedLogAidId = nil
        showsLogSheet = false
    }

    func saveLog(for hearingAid: HearingAid, timestamp: Date, note: String?, context: ModelContext) {
        do {
            let consumedPack = try batteryLogService.quickLog(
                for: hearingAid,
                timestamp: timestamp,
                note: note,
                selectedPackId: selectedPackId,
                selectedLotId: selectedLotId,
                context: context
            )
            errorMessage = nil
            showsInventoryWarning = !consumedPack
            Task {
                await notificationService.rescheduleNotifications(for: hearingAid.id, context: context)
                await notificationService.notifyLowBatteryPacksIfNeeded(
                    context: context,
                    preferredPackId: selectedPackId
                )
            }
            endLog()
        } catch {
            errorMessage = "Could not save battery log."
        }
    }

    /// Resolves the selected aid ID to a HearingAid from the provided array.
    func resolvedAid(from aids: [HearingAid]) -> HearingAid? {
        guard let id = selectedLogAidId else { return nil }
        return aids.first { $0.id == id }
    }

    /// Returns the active hearing aid whose battery is predicted to die soonest.
    func aidNextToDie(from activeAids: [HearingAid], context: ModelContext) -> HearingAid? {
        var closest: (aid: HearingAid, death: Date)?

        for aid in activeAids {
            let snapshot = statsService.statsSnapshot(for: aid.id, windowSize: 10, context: context)
            guard let predicted = snapshot.predictedDeath else { continue }
            if closest == nil || predicted < closest!.death {
                closest = (aid, predicted)
            }
        }

        return closest?.aid
    }

    func dismissInventoryWarning() {
        showsInventoryWarning = false
    }
}
