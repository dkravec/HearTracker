//
//  ExchangeRateService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import Foundation

/// Fetches exchange rates from a free API, caches them locally,
/// and falls back to bundled static rates when offline.
///
/// Rates are relative to USD (base currency).
actor ExchangeRateService {

    // MARK: - Shared instance

    static let shared = ExchangeRateService()

    // MARK: - Types

    struct Rates: Codable {
        let base: String
        let rates: [String: Double]
        let fetchedAt: Date
    }

    // MARK: - State

    private var cachedRates: Rates?
    private let cacheKey = "ExchangeRateService.cachedRates"
    /// Re-fetch if cache is older than 24 hours.
    private let staleDuration: TimeInterval = 86_400

    // MARK: - Public API

    /// Get the conversion rate from `sourceCurrency` to `targetCurrency`.
    /// Tries cached → network → bundled fallback.
    func rate(from source: String, to target: String) async -> Double? {
        let src = source.uppercased()
        let tgt = target.uppercased()
        guard src != tgt else { return 1.0 }

        let rates = await currentRates()
        guard let srcRate = rates.rates[src],
              let tgtRate = rates.rates[tgt],
              srcRate > 0 else { return nil }

        return tgtRate / srcRate
    }

    /// Convert a `Decimal` amount between currencies.
    func convert(_ amount: Decimal, from source: String, to target: String) async -> Decimal? {
        guard let r = await rate(from: source, to: target) else { return nil }
        return amount * Decimal(r)
    }

    /// Force a fresh fetch from the network if possible.
    func refresh() async {
        if let fetched = await fetchFromNetwork() {
            cachedRates = fetched
            persistToDefaults(fetched)
        }
    }

    // MARK: - Rate resolution

    private func currentRates() async -> Rates {
        // 1. In-memory cache
        if let cached = cachedRates, !isStale(cached) {
            return cached
        }

        // 2. Disk cache
        if cachedRates == nil, let disk = loadFromDefaults() {
            cachedRates = disk
            if !isStale(disk) {
                return disk
            }
        }

        // 3. Network
        if let fetched = await fetchFromNetwork() {
            cachedRates = fetched
            persistToDefaults(fetched)
            return fetched
        }

        // 4. Stale cache is still better than nothing
        if let cached = cachedRates {
            return cached
        }

        // 5. Bundled fallback
        return Self.bundledRates
    }

    private func isStale(_ rates: Rates) -> Bool {
        Date().timeIntervalSince(rates.fetchedAt) > staleDuration
    }

    // MARK: - Network

    /// Uses the free Open Exchange Rates API (no key required for this endpoint).
    private func fetchFromNetwork() async -> Rates? {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            struct APIResponse: Decodable {
                let result: String
                let base_code: String
                let rates: [String: Double]
            }

            let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
            guard decoded.result == "success" else { return nil }

            return Rates(
                base: decoded.base_code,
                rates: decoded.rates,
                fetchedAt: Date()
            )
        } catch {
            return nil
        }
    }

    // MARK: - Disk cache (UserDefaults)

    private func persistToDefaults(_ rates: Rates) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadFromDefaults() -> Rates? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(Rates.self, from: data)
    }

    // MARK: - Bundled fallback rates (approximate, updated 2026-02-28)

    static let bundledRates = Rates(
        base: "USD",
        rates: [
            "USD": 1.0,
            "CAD": 1.44,
            "EUR": 0.96,
            "GBP": 0.80,
            "AUD": 1.60,
            "NZD": 1.76,
            "CHF": 0.91,
            "SEK": 10.92,
            "NOK": 11.18,
            "DKK": 7.14,
            "JPY": 150.50,
            "INR": 83.50,
            "BRL": 5.80,
            "MXN": 20.50,
        ],
        fetchedAt: Date(timeIntervalSince1970: 0) // always stale → triggers fetch
    )
}
