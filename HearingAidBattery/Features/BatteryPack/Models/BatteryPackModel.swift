//
//  BatteryPackModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

@Model
final class BatteryPack {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var spaceId: UUID = Space.defaultSpaceId

    var batteryType: String = ""
    var purchaseDate: Date = Date()

    var batteriesPerPack: Int = 0
    var numberOfPacks: Int = 0
    var quantityPurchased: Int = 0
    var quantityRemaining: Int = 0
    var isDone: Bool = false
    var isMarkedLost: Bool = false

    var priceAmount: Decimal?
    var currencyCode: String?   // "EUR", "CAD"

    var brand: String?
    var retailer: String?
    var note: String?

    @Relationship(deleteRule: .nullify, inverse: \BatteryLog.batteryPack)
    var logs: [BatteryLog]?

    init(
         spaceId: UUID = Space.defaultSpaceId,
         batteryType: String,
         purchaseDate: Date = Date(),
         batteriesPerPack: Int,
         numberOfPacks: Int,
         priceAmount: Decimal? = nil,
         currencyCode: String? = nil,
         brand: String? = nil
    ) {
        self.spaceId = spaceId
        self.batteryType = batteryType
        self.purchaseDate = purchaseDate
        self.batteriesPerPack = batteriesPerPack
        self.numberOfPacks = numberOfPacks
        let totalBatteries = max(1, batteriesPerPack * numberOfPacks)
        self.quantityPurchased = totalBatteries
        self.quantityRemaining = totalBatteries
        self.isDone = false
        self.isMarkedLost = false
        self.priceAmount = priceAmount
        self.currencyCode = currencyCode
        self.brand = brand
    }
}
