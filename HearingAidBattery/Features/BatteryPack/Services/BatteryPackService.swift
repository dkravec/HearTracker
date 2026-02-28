//
//  BatteryPackService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

@MainActor
final class BatteryPackService {
    func createBatteryPack(
        for hearingAid: HearingAid,
        batteryType: String,
        purchaseDate: Date,
        quantityPurchased: Int,
        priceAmount: Decimal? = nil,
        currencyCode: String? = nil,
        retailer: String? = nil,
        note: String? = nil,
        context: ModelContext
    ) throws {
        let pack = BatteryPack(
            hearingAid: hearingAid,
            batteryType: batteryType,
            purchaseDate: purchaseDate,
            quantityPurchased: quantityPurchased,
            priceAmount: priceAmount,
            currencyCode: currencyCode
        )

        pack.retailer = retailer?.trimmingCharacters(in: .whitespacesAndNewlines)
        pack.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        context.insert(pack)
        try context.save()
    }

    func deleteBatteryPack(_ batteryPack: BatteryPack, context: ModelContext) throws {
        context.delete(batteryPack)
        try context.save()
    }
}
