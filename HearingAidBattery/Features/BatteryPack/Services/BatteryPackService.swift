//
//  BatteryPackService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

enum BatteryPackServiceError: LocalizedError {
    case invalidUsageCount
    case usageExceedsAvailable
    case packMarkedDone

    var errorDescription: String? {
        switch self {
        case .invalidUsageCount:
            return "Enter at least 1 battery."
        case .usageExceedsAvailable:
            return "Cannot use more batteries than are remaining in this pack."
        case .packMarkedDone:
            return "This pack is marked done. Mark it active to use it."
        }
    }
}

struct BatteryPackCostStat {
    let currencyCode: String
    let averageCostPerBattery: Decimal
    let costPerDay: Decimal?
}

@MainActor
final class BatteryPackService {
    func createBatteryPack(
        batteryType: String,
        purchaseDate: Date,
        batteriesPerPack: Int,
        numberOfPacks: Int,
        priceAmount: Decimal? = nil,
        currencyCode: String? = nil,
        brand: String? = nil,
        retailer: String? = nil,
        note: String? = nil,
        context: ModelContext
    ) throws {
        let normalized = normalizedPackInput(
            batteryType: batteryType,
            batteriesPerPack: batteriesPerPack,
            numberOfPacks: numberOfPacks,
            brand: brand,
            retailer: retailer,
            note: note,
            priceAmount: priceAmount,
            currencyCode: currencyCode
        )
        let pack = BatteryPack(
            spaceId: SpaceService.currentSpaceId(context: context),
            batteryType: normalized.batteryType,
            purchaseDate: purchaseDate,
            batteriesPerPack: normalized.batteriesPerPack,
            numberOfPacks: normalized.numberOfPacks,
            priceAmount: normalized.priceAmount,
            currencyCode: normalized.currencyCode,
            brand: normalized.brand
        )

        pack.retailer = normalized.retailer
        pack.note = normalized.note

        context.insert(pack)
        try context.save()
    }

    func updatePack(
        _ batteryPack: BatteryPack,
        batteryType: String,
        purchaseDate: Date,
        batteriesPerPack: Int,
        numberOfPacks: Int,
        priceAmount: Decimal? = nil,
        currencyCode: String? = nil,
        brand: String? = nil,
        retailer: String? = nil,
        note: String? = nil,
        context: ModelContext
    ) throws {
        let normalized = normalizedPackInput(
            batteryType: batteryType,
            batteriesPerPack: batteriesPerPack,
            numberOfPacks: numberOfPacks,
            brand: brand,
            retailer: retailer,
            note: note,
            priceAmount: priceAmount,
            currencyCode: currencyCode
        )

        let usedCount = usedBatteries(for: batteryPack)
        let purchased = normalized.batteriesPerPack * normalized.numberOfPacks

        batteryPack.batteryType = normalized.batteryType
        batteryPack.purchaseDate = purchaseDate
        batteryPack.batteriesPerPack = normalized.batteriesPerPack
        batteryPack.numberOfPacks = normalized.numberOfPacks
        batteryPack.quantityPurchased = purchased
        batteryPack.quantityRemaining = remainingBatteries(purchased: purchased, used: usedCount)
        batteryPack.priceAmount = normalized.priceAmount
        batteryPack.currencyCode = normalized.currencyCode
        batteryPack.brand = normalized.brand
        batteryPack.retailer = normalized.retailer
        batteryPack.note = normalized.note

        try context.save()
    }

    func deletePack(_ batteryPack: BatteryPack, context: ModelContext) throws {
        context.delete(batteryPack)
        try context.save()
    }

    func useBatteries(
        _ countUsed: Int,
        note: String? = nil,
        timestamp: Date = Date(),
        from batteryPack: BatteryPack,
        context: ModelContext
    ) throws {
        let normalizedCount = max(0, countUsed)
        guard normalizedCount > 0 else {
            throw BatteryPackServiceError.invalidUsageCount
        }
        guard batteryPack.isDone == false else {
            throw BatteryPackServiceError.packMarkedDone
        }
        guard normalizedCount <= batteryPack.quantityRemaining else {
            throw BatteryPackServiceError.usageExceedsAvailable
        }

        applyUsage(count: normalizedCount, to: batteryPack)
        appendUsageNote(note, count: normalizedCount, timestamp: timestamp, to: batteryPack)
        try context.save()
    }

    func restoreOneBattery(
        in batteryPack: BatteryPack,
        context: ModelContext
    ) throws {
        guard batteryPack.quantityRemaining < batteryPack.quantityPurchased else { return }
        batteryPack.quantityRemaining += 1
        try context.save()
    }

    func consumeOneBattery(
        selectedPackId: UUID?,
        preferredBatteryType: String?,
        spaceId: UUID,
        context: ModelContext
    ) -> BatteryPack? {
        let descriptor = FetchDescriptor<BatteryPack>(
            predicate: #Predicate<BatteryPack> {
                $0.quantityRemaining > 0 && $0.isDone == false && $0.spaceId == spaceId
            },
            sortBy: [SortDescriptor(\BatteryPack.purchaseDate, order: .forward)]
        )

        let packs = (try? context.fetch(descriptor)) ?? []
        let selectedPack: BatteryPack? = {
            guard let selectedPackId else { return nil }
            return packs.first(where: { $0.id == selectedPackId })
        }()
        let matchedPack: BatteryPack? = {
            guard let preferredBatteryType else { return nil }
            let normalizedType = preferredBatteryType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedType.isEmpty == false else { return nil }
            return packs.first {
                $0.batteryType.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(normalizedType) == .orderedSame
            }
        }()

        guard let packToConsume = selectedPack ?? matchedPack ?? packs.first else {
            return nil
        }

        applyUsage(count: 1, to: packToConsume)
        return packToConsume
    }

    func markPackDone(
        _ batteryPack: BatteryPack,
        markLost: Bool,
        context: ModelContext
    ) throws {
        batteryPack.isDone = true
        batteryPack.isMarkedLost = markLost
        try context.save()
    }

    func unmarkPackDone(
        _ batteryPack: BatteryPack,
        context: ModelContext
    ) throws {
        batteryPack.isDone = false
        batteryPack.isMarkedLost = false
        try context.save()
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

    private func remainingBatteries(purchased: Int, used: Int) -> Int {
        max(0, purchased - max(0, used))
    }

    private func usedBatteries(for pack: BatteryPack) -> Int {
        max(0, pack.quantityPurchased - pack.quantityRemaining)
    }

    private func applyUsage(count: Int, to pack: BatteryPack) {
        let used = usedBatteries(for: pack) + max(0, count)
        pack.quantityRemaining = remainingBatteries(purchased: pack.quantityPurchased, used: used)
    }

    private func appendUsageNote(_ note: String?, count: Int, timestamp: Date, to pack: BatteryPack) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false else { return }
        let entry = "[\(timestamp.formatted(date: .abbreviated, time: .shortened))] Used \(count): \(trimmed)"
        let existing = pack.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        pack.note = existing.isEmpty ? entry : "\(existing)\n\(entry)"
    }

    private func normalizedPackInput(
        batteryType: String,
        batteriesPerPack: Int,
        numberOfPacks: Int,
        brand: String?,
        retailer: String?,
        note: String?,
        priceAmount: Decimal?,
        currencyCode: String?
    ) -> (
        batteryType: String,
        batteriesPerPack: Int,
        numberOfPacks: Int,
        brand: String?,
        retailer: String?,
        note: String?,
        priceAmount: Decimal?,
        currencyCode: String?
    ) {
        let normalizedType = batteryType.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBrand = normalizedOptionalText(brand)
        let normalizedRetailer = normalizedOptionalText(retailer)
        let normalizedNote = normalizedOptionalText(note)
        let normalizedCurrency = normalizedOptionalText(currencyCode)?.uppercased()
        return (
            batteryType: normalizedType,
            batteriesPerPack: max(1, batteriesPerPack),
            numberOfPacks: max(1, numberOfPacks),
            brand: normalizedBrand,
            retailer: normalizedRetailer,
            note: normalizedNote,
            priceAmount: priceAmount,
            currencyCode: normalizedCurrency
        )
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
