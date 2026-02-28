//
//  CurrencyFormatterTests.swift
//  HearingAidBatteryTests
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation
import Testing
@testable import HearingAidBattery

struct CurrencyFormatterTests {
    private let formatter = CurrencyFormatter.shared

    @Test
    func formatUSD() {
        let result = formatter.format(Decimal(12.5), currencyCode: "USD")
        // Should produce something like "$12.50" — locale-dependent symbol placement.
        #expect(result.contains("12"))
        #expect(result.contains("50"))
    }

    @Test
    func formatCAD() {
        let result = formatter.format(Decimal(7), currencyCode: "CAD")
        #expect(result.contains("7"))
    }

    @Test
    func pricePerBatteryReturnsNilWhenMissingData() {
        #expect(formatter.pricePerBattery(priceAmount: nil, quantityPurchased: 10, currencyCode: "USD") == nil)
        #expect(formatter.pricePerBattery(priceAmount: Decimal(10), quantityPurchased: 0, currencyCode: "USD") == nil)
        #expect(formatter.pricePerBattery(priceAmount: Decimal(10), quantityPurchased: 5, currencyCode: nil) == nil)
    }

    @Test
    func pricePerBatteryFormatsCorrectly() {
        let result = formatter.pricePerBattery(priceAmount: Decimal(20), quantityPurchased: 10, currencyCode: "USD")
        #expect(result != nil)
        #expect(result!.contains("2"))
    }

    @Test
    func costPerDaySummaryEmptyReturnsNotEnoughData() {
        #expect(formatter.costPerDaySummary(from: []) == "Not enough data")
    }

    @Test
    func costPerDaySummarySingleCurrency() {
        let stat = BatteryPackCostStat(
            currencyCode: "USD",
            averageCostPerBattery: Decimal(2),
            costPerDay: Decimal(string: "0.5")!
        )
        let result = formatter.costPerDaySummary(from: [stat])
        #expect(result.contains("/day"))
        #expect(!result.contains("+"))
    }

    @Test
    func costPerDaySummaryMultipleCurrencies() {
        let usd = BatteryPackCostStat(currencyCode: "USD", averageCostPerBattery: Decimal(2), costPerDay: Decimal(string: "0.5")!)
        let cad = BatteryPackCostStat(currencyCode: "CAD", averageCostPerBattery: Decimal(3), costPerDay: Decimal(string: "0.7")!)
        let result = formatter.costPerDaySummary(from: [usd, cad])
        #expect(result.contains("/day"))
        #expect(result.contains("+1"))
    }

    @Test
    func costPerDaySummaryNilCostPerDay() {
        let stat = BatteryPackCostStat(currencyCode: "USD", averageCostPerBattery: Decimal(2), costPerDay: nil)
        #expect(formatter.costPerDaySummary(from: [stat]) == "Not enough data")
    }

    @Test
    func decimalFromInputParsesDot() {
        let result = CurrencyFormatter.decimalFromInput("12.50")
        #expect(result == Decimal(string: "12.50"))
    }

    @Test
    func decimalFromInputTrimsWhitespace() {
        let result = CurrencyFormatter.decimalFromInput("  42  ")
        #expect(result == Decimal(42))
    }

    @Test
    func decimalFromInputEmptyReturnsNil() {
        #expect(CurrencyFormatter.decimalFromInput("") == nil)
        #expect(CurrencyFormatter.decimalFromInput("   ") == nil)
    }

    @Test
    func localeCurrencyCodeIsNonEmpty() {
        #expect(!CurrencyFormatter.localeCurrencyCode.isEmpty)
    }

    @Test
    func commonCurrencyCodesContainsExpected() {
        let codes = CurrencyFormatter.commonCurrencyCodes
        #expect(codes.contains("USD"))
        #expect(codes.contains("EUR"))
        #expect(codes.contains("CAD"))
        #expect(codes.contains("GBP"))
    }
}

struct ExchangeRateServiceTests {
    @Test
    func bundledRatesContainCommonCurrencies() {
        let rates = ExchangeRateService.bundledRates
        #expect(rates.rates["USD"] == 1.0)
        #expect(rates.rates["CAD"] != nil)
        #expect(rates.rates["EUR"] != nil)
        #expect(rates.rates["GBP"] != nil)
        #expect(rates.rates["JPY"] != nil)
    }

    @Test
    func sameCurrencyReturnsOne() async {
        let rate = await ExchangeRateService.shared.rate(from: "USD", to: "USD")
        #expect(rate == 1.0)
    }

    @Test
    func convertSameCurrencyReturnsOriginal() async {
        let result = await ExchangeRateService.shared.convert(Decimal(10), from: "CAD", to: "CAD")
        #expect(result == Decimal(10))
    }
}
