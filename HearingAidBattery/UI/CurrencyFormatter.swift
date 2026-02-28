//
//  CurrencyFormatter.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation

/// Centralized, cached currency formatting for the app.
/// Avoids repeated `NumberFormatter` allocations and provides
/// locale-aware helpers for currency display and input parsing.
struct CurrencyFormatter {

    // MARK: - Shared instance

    /// Use this for quick access; the struct is value-typed but all
    /// heavy state lives in the class-based cache.
    static let shared = CurrencyFormatter()

    // MARK: - Formatter cache

    /// One `NumberFormatter` per currency code, lazily built.
    private static let cache = FormatterCache()

    // MARK: - Public API

    /// The user's locale-derived currency code, e.g. `"CAD"`, `"EUR"`.
    static var localeCurrencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Format a `Decimal` amount as a localized currency string.
    /// Uses the user's locale for grouping / decimal separators
    /// and the given `currencyCode` for the symbol.
    ///
    /// Example: `format(1.5, currencyCode: "USD")` → `"$1.50"`
    func format(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = Self.cache.formatter(for: currencyCode)
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? number.stringValue
    }

    /// Convenience: format the price-per-battery for a given pack.
    /// Returns `nil` when the pack has no price or zero quantity.
    func pricePerBattery(priceAmount: Decimal?, quantityPurchased: Int, currencyCode: String?) -> String? {
        guard let amount = priceAmount,
              let code = currencyCode,
              quantityPurchased > 0 else { return nil }
        let perBattery = amount / Decimal(quantityPurchased)
        return format(perBattery, currencyCode: code)
    }

    /// Build a human-readable cost-per-day summary from one or more
    /// `BatteryPackCostStat` values. Shows one line if a single
    /// currency is present; shows the first with a `"+N"` indicator
    /// when multiple currencies exist.
    ///
    /// Example: `"$0.13/day"` or `"$0.13/day +1"`
    func costPerDaySummary(from costStats: [BatteryPackCostStat]) -> String {
        guard !costStats.isEmpty else { return "Not enough data" }

        let pieces = costStats.compactMap { stat -> String? in
            guard let costPerDay = stat.costPerDay else { return nil }
            let formatted = format(costPerDay, currencyCode: stat.currencyCode)
            return "\(formatted)/day"
        }

        if pieces.isEmpty { return "Not enough data" }
        if pieces.count == 1 { return pieces[0] }
        return "\(pieces[0]) +\(pieces.count - 1)"
    }

    /// Build a cost-per-day summary that converts all currencies into
    /// `targetCurrency` using exchange rates, producing a single unified number.
    /// Falls back to per-currency display if conversion isn't available.
    func costPerDaySummaryConverted(
        from costStats: [BatteryPackCostStat],
        targetCurrency: String
    ) async -> String {
        guard !costStats.isEmpty else { return "Not enough data" }

        let statsWithCost = costStats.filter { $0.costPerDay != nil }
        guard !statsWithCost.isEmpty else { return "Not enough data" }

        // Only one currency present — no conversion needed at all.
        let uniqueCurrencies = Set(statsWithCost.map { $0.currencyCode.uppercased() })
        if uniqueCurrencies.count == 1 {
            return costPerDaySummary(from: costStats)
        }

        let exchangeService = ExchangeRateService.shared
        var totalConverted: Decimal = 0
        var conversionFailed = false

        for stat in statsWithCost {
            guard let costPerDay = stat.costPerDay else { continue }
            if stat.currencyCode.uppercased() == targetCurrency.uppercased() {
                totalConverted += costPerDay
            } else if let converted = await exchangeService.convert(costPerDay, from: stat.currencyCode, to: targetCurrency) {
                totalConverted += converted
            } else {
                conversionFailed = true
            }
        }

        if conversionFailed {
            // Couldn't convert everything — fall back to per-currency display.
            return costPerDaySummary(from: costStats)
        }

        let formatted = format(totalConverted, currencyCode: targetCurrency)
        return "\(formatted)/day"
    }

    // MARK: - Input parsing

    /// Parse a price string from user input in a locale-aware way.
    /// Handles both `"12.50"` and `"12,50"` depending on locale
    /// as well as plain number strings.
    static func decimalFromInput(_ input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try the user's locale first (handles comma decimals).
        let localeFormatter = NumberFormatter()
        localeFormatter.numberStyle = .decimal
        localeFormatter.locale = .current
        if let number = localeFormatter.number(from: trimmed) {
            return number.decimalValue
        }

        // Fall back to a plain Decimal parse (POSIX-style).
        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - Well-known currencies

    /// ISO 4217 codes commonly used for hearing-aid battery purchases.
    static let commonCurrencyCodes: [String] = [
        "USD", "CAD", "EUR", "GBP", "AUD", "NZD",
        "CHF", "SEK", "NOK", "DKK", "JPY", "INR", "BRL", "MXN"
    ]
}

// MARK: - Internal cache

private final class FormatterCache: @unchecked Sendable {
    private var formatters: [String: NumberFormatter] = [:]
    private let lock = NSLock()

    func formatter(for currencyCode: String) -> NumberFormatter {
        let key = currencyCode.uppercased()
        lock.lock()
        defer { lock.unlock() }

        if let existing = formatters[key] {
            return existing
        }

        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = key
        formatters[key] = f
        return f
    }
}
