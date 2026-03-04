//
//  BatteryPackModel.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation
import SwiftData

@Model
final class BatteryPackLot {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var openedAt: Date?
    var quantityInitial: Int = 0
    var quantityRemaining: Int = 0
    var isMarkedLost: Bool = false
    var note: String?

    var pack: BatteryPack?

    init(
        sortIndex: Int,
        quantityInitial: Int,
        quantityRemaining: Int,
        openedAt: Date? = nil,
        isMarkedLost: Bool = false,
        note: String? = nil
    ) {
        self.sortIndex = sortIndex
        self.quantityInitial = max(0, quantityInitial)
        self.quantityRemaining = min(max(0, quantityRemaining), max(0, quantityInitial))
        self.openedAt = openedAt
        self.isMarkedLost = isMarkedLost
        self.note = note
    }

    var hasCapacityToRestore: Bool {
        quantityRemaining < quantityInitial
    }
}

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

    @Relationship(deleteRule: .cascade, inverse: \BatteryPackLot.pack)
    var lots: [BatteryPackLot]? = []

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

    var totalPurchasedComputed: Int {
        let normalizedLots = sortedLots
        guard normalizedLots.isEmpty == false else { return max(0, quantityPurchased) }
        return normalizedLots.reduce(0) { $0 + max(0, $1.quantityInitial) }
    }

    var totalRemainingComputed: Int {
        let normalizedLots = sortedLots
        guard normalizedLots.isEmpty == false else { return max(0, quantityRemaining) }
        return normalizedLots.reduce(0) { $0 + max(0, $1.quantityRemaining) }
    }

    var totalUsedComputed: Int {
        max(0, totalPurchasedComputed - totalRemainingComputed)
    }

    func ensureLotsIfNeeded() {
        let existingLots = sortedLots
        if existingLots.isEmpty == false {
            syncLegacyTotals()
            return
        }

        let packCount = max(0, numberOfPacks)
        let perPack = max(0, batteriesPerPack)
        let totalCapacity = packCount * perPack
        guard packCount > 0, perPack > 0, totalCapacity > 0 else {
            syncLegacyTotals()
            return
        }

        var createdLots: [BatteryPackLot] = []
        for index in 0..<packCount {
            createdLots.append(
                BatteryPackLot(
                    sortIndex: index,
                    quantityInitial: perPack,
                    quantityRemaining: perPack
                )
            )
        }

        var remainingToDistribute = min(max(0, quantityRemaining), totalCapacity)
        for lot in createdLots.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let restoredInLot = min(perPack, remainingToDistribute)
            lot.quantityRemaining = restoredInLot
            remainingToDistribute -= restoredInLot
        }

        lots = createdLots
        syncLegacyTotals()
    }

    func rebuildLotsForCurrentConfiguration() {
        lots = []
        ensureLotsIfNeeded()
    }

    func syncTotalsFromLots() {
        syncLegacyTotals()
    }

    @discardableResult
    func consume(count: Int, fromLotId: UUID? = nil, date: Date = Date()) -> Int {
        let normalizedCount = max(0, count)
        guard normalizedCount > 0 else { return 0 }

        if sortedLots.isEmpty {
            let consumed = min(normalizedCount, max(0, quantityRemaining))
            quantityRemaining = max(0, quantityRemaining - consumed)
            if quantityRemaining <= 0 {
                isDone = true
            }
            return consumed
        }

        var remaining = normalizedCount

        if let fromLotId,
           let preferredLot = sortedLots.first(where: {
               $0.id == fromLotId && $0.isMarkedLost == false && $0.quantityRemaining > 0
           }) {
            let available = max(0, preferredLot.quantityRemaining)
            let used = min(remaining, available)
            preferredLot.quantityRemaining = available - used
            if preferredLot.openedAt == nil {
                preferredLot.openedAt = date
            }
            remaining -= used
        }

        for lot in consumeOrder(preferredLotId: nil) where remaining > 0 {
            guard fromLotId != lot.id else { continue }
            let available = max(0, lot.quantityRemaining)
            guard available > 0 else { continue }
            let used = min(remaining, available)
            lot.quantityRemaining = available - used
            if lot.openedAt == nil {
                lot.openedAt = date
            }
            remaining -= used
        }

        let consumed = normalizedCount - remaining
        syncLegacyTotals()
        return consumed
    }

    @discardableResult
    func restore(count: Int, toLotId: UUID? = nil) -> Int {
        let normalizedCount = max(0, count)
        guard normalizedCount > 0 else { return 0 }

        if sortedLots.isEmpty {
            let capacity = max(0, quantityPurchased - quantityRemaining)
            let restored = min(normalizedCount, capacity)
            quantityRemaining = min(quantityPurchased, quantityRemaining + restored)
            return restored
        }

        var remaining = normalizedCount
        for lot in restoreOrder(preferredLotId: toLotId) where remaining > 0 {
            guard lot.isMarkedLost == false else { continue }
            let currentRemaining = max(0, lot.quantityRemaining)
            let capacity = max(0, lot.quantityInitial - currentRemaining)
            guard capacity > 0 else { continue }
            let restored = min(remaining, capacity)
            lot.quantityRemaining = currentRemaining + restored
            // A fully restored lot is considered unopened inventory again.
            if lot.quantityRemaining >= lot.quantityInitial {
                lot.openedAt = nil
            }
            remaining -= restored
        }

        let restored = normalizedCount - remaining
        syncLegacyTotals()
        return restored
    }

    @discardableResult
    func consumeFromSpecificLot(lotId: UUID, count: Int = 1, date: Date = Date()) -> Int {
        let normalizedCount = max(0, count)
        guard normalizedCount > 0 else { return 0 }
        guard let lot = sortedLots.first(where: { $0.id == lotId && $0.isMarkedLost == false }) else {
            return 0
        }
        let available = max(0, lot.quantityRemaining)
        let consumed = min(normalizedCount, available)
        guard consumed > 0 else { return 0 }
        lot.quantityRemaining = available - consumed
        if lot.openedAt == nil {
            lot.openedAt = date
        }
        syncLegacyTotals()
        return consumed
    }

    @discardableResult
    func restoreToSpecificLot(lotId: UUID, count: Int = 1) -> Int {
        let normalizedCount = max(0, count)
        guard normalizedCount > 0 else { return 0 }
        guard let lot = sortedLots.first(where: { $0.id == lotId && $0.isMarkedLost == false }) else {
            return 0
        }
        let currentRemaining = max(0, lot.quantityRemaining)
        let capacity = max(0, lot.quantityInitial - currentRemaining)
        let restored = min(normalizedCount, capacity)
        guard restored > 0 else { return 0 }
        lot.quantityRemaining = currentRemaining + restored
        if lot.quantityRemaining >= lot.quantityInitial {
            lot.openedAt = nil
        }
        syncLegacyTotals()
        return restored
    }

    private var sortedLots: [BatteryPackLot] {
        (lots ?? []).sorted { lhs, rhs in
            if lhs.sortIndex == rhs.sortIndex {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    private func consumeOrder(preferredLotId: UUID?) -> [BatteryPackLot] {
        let candidates = sortedLots.filter { $0.isMarkedLost == false && $0.quantityRemaining > 0 }
        let opened = candidates
            .filter { $0.openedAt != nil }
            .sorted {
                guard let left = $0.openedAt, let right = $1.openedAt else { return false }
                return left < right
            }
        let unopened = candidates
            .filter { $0.openedAt == nil }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
        let auto = opened + unopened
        return withPreferredLot(preferredLotId, in: auto)
    }

    private func restoreOrder(preferredLotId: UUID?) -> [BatteryPackLot] {
        let candidates = sortedLots.filter {
            $0.isMarkedLost == false && $0.quantityRemaining < $0.quantityInitial
        }
        let opened = candidates
            .filter { $0.openedAt != nil }
            .sorted {
                guard let left = $0.openedAt, let right = $1.openedAt else { return false }
                return left > right
            }
        let unopened = candidates
            .filter { $0.openedAt == nil }
            .sorted(by: { $0.sortIndex > $1.sortIndex })
        let auto = opened + unopened
        return withPreferredLot(preferredLotId, in: auto)
    }

    private func withPreferredLot(_ preferredLotId: UUID?, in orderedLots: [BatteryPackLot]) -> [BatteryPackLot] {
        guard let preferredLotId,
              let preferredIndex = orderedLots.firstIndex(where: { $0.id == preferredLotId }) else {
            return orderedLots
        }

        var reordered = orderedLots
        let preferred = reordered.remove(at: preferredIndex)
        reordered.insert(preferred, at: 0)
        return reordered
    }

    private func syncLegacyTotals() {
        quantityPurchased = totalPurchasedComputed
        quantityRemaining = totalRemainingComputed
        if quantityRemaining <= 0 {
            isDone = true
        } else if isMarkedLost {
            isDone = true
        }
    }
}
