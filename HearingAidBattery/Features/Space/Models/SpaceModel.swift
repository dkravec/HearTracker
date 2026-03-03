//
//  SpaceModel.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-03.
//

import Foundation
import SwiftData

@Model
final class Space {
    @Attribute(.unique) var id: UUID
    var name: String
    var roleHint: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Personal",
        roleHint: String = "self",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.roleHint = roleHint
        self.createdAt = createdAt
    }
}

extension Space {
    static let defaultSpaceId = UUID(uuidString: "2C01CA48-8D6D-4BA2-8AFB-BD80B85FF45A")!

    static func makeDefaultSpace(name: String = "Personal", roleHint: String = "self") -> Space {
        Space(id: defaultSpaceId, name: name, roleHint: roleHint)
    }
}
