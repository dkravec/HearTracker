//
//  SpaceService.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-03.
//

import Foundation
import SwiftData

@MainActor
enum SpaceService {
    private static let activeSpaceIdKey = "activeSpaceId"

    static func currentSpaceId(context: ModelContext) -> UUID {
        do {
            let defaultSpace = try ensureDefaultSpaceExists(in: context)
            if let activeSpaceId = storedActiveSpaceId(),
               try spaceExists(id: activeSpaceId, in: context) {
                if context.hasChanges {
                    try context.save()
                }
                return activeSpaceId
            }

            UserDefaults.standard.set(defaultSpace.id.uuidString, forKey: activeSpaceIdKey)
            if context.hasChanges {
                try context.save()
            }
            return defaultSpace.id
        } catch {
#if DEBUG
            print("Space bootstrap failed: \(error)")
#endif
            return Space.defaultSpaceId
        }
    }

    static func persistCurrentSpace(spaceId: UUID) {
        UserDefaults.standard.set(spaceId.uuidString, forKey: activeSpaceIdKey)
    }

    static var activeSpaceIdForQueries: UUID {
        storedActiveSpaceId() ?? Space.defaultSpaceId
    }

    @discardableResult
    private static func ensureDefaultSpaceExists(in context: ModelContext) throws -> Space {
        let defaultSpaceId = Space.defaultSpaceId
        let descriptor = FetchDescriptor<Space>(
            predicate: #Predicate { $0.id == defaultSpaceId }
        )

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let created = Space.makeDefaultSpace()
        context.insert(created)
        return created
    }

    private static func storedActiveSpaceId() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: activeSpaceIdKey) else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    private static func spaceExists(id: UUID, in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Space>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first != nil
    }
}
