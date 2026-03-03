//
//  ActiveSpaceSelectionService.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-03.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ActiveSpaceSelectionService: ObservableObject {
    @Published private(set) var activeSpaceId: UUID = Space.defaultSpaceId
    private var hasBootstrapped = false

    func bootstrap(context: ModelContext) {
        guard hasBootstrapped == false else { return }
        hasBootstrapped = true
        updateActiveSpaceId(SpaceService.currentSpaceId(context: context))
    }

    func setCurrentSpace(_ spaceId: UUID, context: ModelContext) {
        SpaceService.persistCurrentSpace(spaceId: spaceId)
        updateActiveSpaceId(SpaceService.currentSpaceId(context: context))
    }

    func refresh(context: ModelContext) {
        updateActiveSpaceId(SpaceService.currentSpaceId(context: context))
    }

    private func updateActiveSpaceId(_ newValue: UUID) {
        guard activeSpaceId != newValue else { return }
        activeSpaceId = newValue
    }
}
