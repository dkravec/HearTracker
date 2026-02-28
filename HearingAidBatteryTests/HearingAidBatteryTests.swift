//
//  HearingAidBatteryTests.swift
//  HearingAidBatteryTests
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation
import SwiftData
import Testing
@testable import HearingAidBattery

@MainActor
struct HearingAidServiceTests {
    @Test
    func createHearingAidTrimsInputs() throws {
        let service = HearingAidService()
        let container = try testContainer()
        let context = ModelContext(container)

        try service.createHearingAid(name: "  My Aid  ", model: "  M50  ", context: context)
        let aids = try context.fetch(FetchDescriptor<HearingAid>())

        #expect(aids.count == 1)
        #expect(aids[0].name == "My Aid")
        #expect(aids[0].model == "M50")
    }

    @Test
    func updateHearingAidRetainsNameWhenBlankAndClearsModel() throws {
        let service = HearingAidService()
        let container = try testContainer()
        let context = ModelContext(container)
        let aid = HearingAid(name: "Original", model: "X")
        context.insert(aid)

        try service.updateHearingAid(aid, name: "   ", model: "   ", retired: true, context: context)

        #expect(aid.name == "Original")
        #expect(aid.model == nil)
        #expect(aid.retired == true)
    }
}

@MainActor
struct BatteryLogServiceTests {
    @Test
    func quickLogConsumesOldestPackAndStoresTrimmedNote() throws {
        let logService = BatteryLogService()
        let container = try testContainer()
        let context = ModelContext(container)
        let aid = HearingAid(name: "A")
        context.insert(aid)

        let olderPack = BatteryPack(
            hearingAid: aid,
            batteryType: "312",
            purchaseDate: Date(timeIntervalSince1970: 1_000),
            quantityPurchased: 6
        )
        let newerPack = BatteryPack(
            hearingAid: aid,
            batteryType: "312",
            purchaseDate: Date(timeIntervalSince1970: 2_000),
            quantityPurchased: 6
        )
        context.insert(olderPack)
        context.insert(newerPack)
        try context.save()

        let consumed = try logService.quickLog(
            for: aid,
            timestamp: Date(timeIntervalSince1970: 9_999),
            note: "  changed battery  ",
            context: context
        )

        let logs = try context.fetch(
            FetchDescriptor<BatteryLog>(
                sortBy: [SortDescriptor(\BatteryLog.timestamp, order: .reverse)]
            )
        ).filter { $0.hearingAid?.id == aid.id }

        #expect(consumed == true)
        #expect(logs.count == 1)
        #expect(logs[0].timestamp == Date(timeIntervalSince1970: 9_999))
        #expect(logs[0].note == "changed battery")
        #expect(olderPack.quantityRemaining == 5)
        #expect(newerPack.quantityRemaining == 6)
    }

    @Test
    func quickLogReturnsFalseWhenNoInventory() throws {
        let logService = BatteryLogService()
        let container = try testContainer()
        let context = ModelContext(container)
        let aid = HearingAid(name: "A")
        context.insert(aid)
        try context.save()

        let consumed = try logService.quickLog(for: aid, timestamp: Date(), note: nil, context: context)

        #expect(consumed == false)
    }
}

@MainActor
struct BatteryPackServiceTests {
    @Test
    func createBatteryPackSetsRemainingAndTrimsOptionalFields() throws {
        let service = BatteryPackService()
        let container = try testContainer()
        let context = ModelContext(container)
        let aid = HearingAid(name: "A")
        context.insert(aid)

        try service.createBatteryPack(
            for: aid,
            batteryType: "312",
            purchaseDate: Date(timeIntervalSince1970: 100),
            quantityPurchased: 12,
            priceAmount: Decimal(24),
            currencyCode: "USD",
            retailer: "  Costco  ",
            note: "  bulk pack  ",
            context: context
        )

        let packs = try context.fetch(FetchDescriptor<BatteryPack>())
        #expect(packs.count == 1)
        #expect(packs[0].quantityRemaining == 12)
        #expect(packs[0].retailer == "Costco")
        #expect(packs[0].note == "bulk pack")
    }

    @Test
    func costStatsByCurrencyReturnsPerCurrencyWeightedValues() {
        let service = BatteryPackService()
        let aid = HearingAid(name: "A")
        let usd1 = BatteryPack(
            hearingAid: aid,
            batteryType: "312",
            quantityPurchased: 10,
            priceAmount: Decimal(20),
            currencyCode: "USD"
        )
        let usd2 = BatteryPack(
            hearingAid: aid,
            batteryType: "312",
            quantityPurchased: 5,
            priceAmount: Decimal(15),
            currencyCode: "USD"
        )
        let cad = BatteryPack(
            hearingAid: aid,
            batteryType: "13",
            quantityPurchased: 8,
            priceAmount: Decimal(16),
            currencyCode: "CAD"
        )

        let stats = service.costStatsByCurrency(from: [usd1, usd2, cad], averageDuration: 86_400)

        #expect(stats.count == 2)
        #expect(stats[0].currencyCode == "CAD")
        #expect(stats[1].currencyCode == "USD")
    }
}

@MainActor
struct IssueLogServiceTests {
    @Test
    func createIssueLogTrimsNoteAndSetsLink() throws {
        let service = IssueLogService()
        let container = try testContainer()
        let context = ModelContext(container)
        let aid = HearingAid(name: "A")
        context.insert(aid)
        let linkedId = UUID()

        try service.createIssueLog(
            for: aid,
            category: "audio",
            severity: 3,
            note: "  static noise  ",
            linkedBatteryLogId: linkedId,
            context: context
        )

        let issues = try context.fetch(FetchDescriptor<IssueLog>())
        #expect(issues.count == 1)
        #expect(issues[0].note == "static noise")
        #expect(issues[0].linkedBatteryLogId == linkedId)
    }
}

struct FormatterTests {
    @Test
    func batteryDurationFormatterProducesDaysText() {
        let formatter = BatteryDurationFormatter()
        #expect(formatter.daysText(from: 172_800) == "2.0 days")
        #expect(formatter.optionalDaysText(from: nil) == nil)
    }
}

private func testContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema([HearingAid.self, BatteryLog.self, BatteryPack.self, IssueLog.self]),
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
}
