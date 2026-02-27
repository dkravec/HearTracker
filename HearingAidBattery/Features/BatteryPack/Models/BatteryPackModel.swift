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

    var batteryType: String
    var purchaseDate: Date = Date()

    var quantityPurchased: Int = 0
    var quantityRemaining: Int = 0

    var priceAmount: Decimal?
    var currencyCode: String?   // "EUR", "CAD"

    var retailer: String?
    var note: String?

    var hearingAid: HearingAid?

    init(
        hearingAid: HearingAid,
         batteryType: String,
         purchaseDate: Date = Date(),
         quantityPurchased: Int,
         priceAmount: Decimal? = nil,
         currencyCode: String? = nil
    ) {
        self.hearingAid = hearingAid
        self.batteryType = batteryType
        self.purchaseDate = purchaseDate
        self.quantityPurchased = quantityPurchased
        self.quantityRemaining = quantityPurchased
        self.priceAmount = priceAmount
        self.currencyCode = currencyCode
    }
}
