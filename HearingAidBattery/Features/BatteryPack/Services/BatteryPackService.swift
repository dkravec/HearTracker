//
//  BatteryPackService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

struct BatteryPackCostStat {
    let currencyCode: String
    let averageCostPerBattery: Decimal
    let costPerDay: Decimal?
}

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

    func consumeOneBatteryFIFO(for hearingAidId: UUID, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<BatteryPack>(
            predicate: #Predicate<BatteryPack> {
                $0.hearingAid?.id == hearingAidId && $0.quantityRemaining > 0
            },
            sortBy: [SortDescriptor(\BatteryPack.purchaseDate, order: .forward)]
        )

        let packs = (try? context.fetch(descriptor)) ?? []
        guard let pack = packs.first else {
            return false
        }

        guard pack.quantityRemaining > 0 else {
            return false
        }

        pack.quantityRemaining -= 1
        return true
    }

    func costStatsByCurrency(from packs: [BatteryPack], averageDuration: TimeInterval?) -> [BatteryPackCostStat] {
        let validPacks = packs.compactMap { pack -> (String, Decimal, Int)? in
            guard
                let amount = pack.priceAmount,
                amount > 0,
                let code = pack.currencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                code.isEmpty == false,
                pack.quantityPurchased > 0
            else {
                return nil
            }
            return (code, amount, pack.quantityPurchased)
        }

        let grouped = Dictionary(grouping: validPacks, by: \.0)
        let days: Double? = {
            guard let averageDuration, averageDuration > 0 else { return nil }
            return averageDuration / 86_400.0
        }()

        return grouped.keys.sorted().compactMap { code in
            guard let entries = grouped[code] else { return nil }
            let totalPrice = entries.reduce(Decimal.zero) { $0 + $1.1 }
            let totalBatteries = entries.reduce(0) { $0 + $1.2 }
            guard totalBatteries > 0 else { return nil }

            let averageCostPerBattery = totalPrice / Decimal(totalBatteries)
            let costPerDay: Decimal? = {
                guard let days, days > 0 else { return nil }
                return averageCostPerBattery / Decimal(days)
            }()

            return BatteryPackCostStat(
                currencyCode: code,
                averageCostPerBattery: averageCostPerBattery,
                costPerDay: costPerDay
            )
        }
    }
}
