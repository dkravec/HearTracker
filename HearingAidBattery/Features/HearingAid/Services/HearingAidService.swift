//
//  HearingAidService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

@MainActor
final class HearingAidService {
    func createHearingAid(name: String, model: String?, context: ModelContext) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = (trimmedModel?.isEmpty == true) ? nil : trimmedModel

        let hearingAid = HearingAid(name: trimmedName, model: normalizedModel)
        context.insert(hearingAid)
        try context.save()
    }

    func updateHearingAid(
        _ hearingAid: HearingAid,
        name: String,
        model: String,
        retired: Bool,
        context: ModelContext
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedName.isEmpty {
            hearingAid.name = trimmedName
        }

        hearingAid.model = trimmedModel.isEmpty ? nil : trimmedModel
        hearingAid.retired = retired

        try context.save()
    }

    func deleteHearingAid(_ hearingAid: HearingAid, context: ModelContext) throws {
        context.delete(hearingAid)
        try context.save()
    }

    func activeAids(from hearingAids: [HearingAid]) -> [HearingAid] {
        hearingAids.filter { !$0.retired }
    }

    func retiredAids(from hearingAids: [HearingAid]) -> [HearingAid] {
        hearingAids.filter { $0.retired }
    }
}
