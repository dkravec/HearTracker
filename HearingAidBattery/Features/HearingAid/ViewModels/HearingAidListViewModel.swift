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
    @Published var showsRetired: Bool = false
    @Published var logTargetAid: HearingAid?
    @Published var logNote: String = ""

    private let hearingAidService: HearingAidService
    private let batteryLogService: BatteryLogProviding

    init(hearingAidService: HearingAidService, batteryLogService: BatteryLogProviding) {
        self.hearingAidService = hearingAidService
        self.batteryLogService = batteryLogService
    }

    convenience init() {
        self.init(hearingAidService: HearingAidService(), batteryLogService: BatteryLogService())
    }

    func activeAids(from hearingAids: [HearingAid]) -> [HearingAid] {
        hearingAidService.activeAids(from: hearingAids)
    }

    func retiredAids(from hearingAids: [HearingAid]) -> [HearingAid] {
        hearingAidService.retiredAids(from: hearingAids)
    }

    func beginLog(for hearingAid: HearingAid) {
        logNote = ""
        logTargetAid = hearingAid
    }

    func endLog() {
        logNote = ""
        logTargetAid = nil
    }

    func saveLog(for hearingAid: HearingAid, note: String?, context: ModelContext) {
        try? batteryLogService.quickLog(for: hearingAid, note: note, context: context)
        endLog()
    }

    func saveLogWithoutNote(for hearingAid: HearingAid, context: ModelContext) {
        try? batteryLogService.quickLog(for: hearingAid, note: nil, context: context)
        endLog()
    }
}
