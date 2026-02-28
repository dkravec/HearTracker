//
//  BatteryPackView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI
import SwiftData

struct BatteryPackListView: View {
    let averageDuration: TimeInterval?

    var body: some View {
        BatteryPackSectionView(
            averageDuration: averageDuration
        )
    }
}

struct BatteryPackView: View {
    let averageDuration: TimeInterval?

    var body: some View {
        BatteryPackListView(
            averageDuration: averageDuration
        )
    }
}

// TODO implement this view
struct BatteryPackSectionView: View {
    @Environment(\.modelContext) private var context

    let averageDuration: TimeInterval?
    @Query(sort: \BatteryPack.purchaseDate, order: .forward) private var packs: [BatteryPack]

    @State private var showsAddPackSheet: Bool = false
    @State private var packPendingDelete: BatteryPack?

    private let batteryPackService = BatteryPackService()

    init(averageDuration: TimeInterval?) {
        self.averageDuration = averageDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeaderView(title: "Battery Packs")
                Spacer(minLength: 8)
                Button("Add Pack") {
                    showsAddPackSheet = true
                }
                .buttonStyle(.borderedProminent)
            }

            if packs.isEmpty {
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No Battery Packs")
                            .font(.headline)
                        Text("Add a battery pack to track inventory and cost.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Add Pack") {
                            showsAddPackSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ForEach(packs) { pack in
                    CardRowContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(pack.batteryType)
                                    .font(.headline)
                                Spacer(minLength: 8)
                                Text("\(pack.quantityRemaining)/\(pack.quantityPurchased) left")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            if let brand = pack.brand, brand.isEmpty == false {
                                Text("Brand: \(brand)")
                                    .font(.subheadline)
                            }

                            Text("Batteries per pack: \(pack.batteriesPerPack)")
                                .font(.subheadline)
                            Text("Number of packs: \(pack.numberOfPacks)")
                                .font(.subheadline)

                            Text("Purchased \(pack.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let priceText = priceText(for: pack) {
                                Text(priceText)
                                    .font(.subheadline)
                            }

                            if let pricePerBatteryText = pricePerBatteryText(for: pack) {
                                Text("Price per battery: \(pricePerBatteryText)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Delete Pack", role: .destructive) {
                            packPendingDelete = pack
                        }
                    }
                }
            }

            let costStats = batteryPackService.costStatsByCurrency(from: packs, averageDuration: averageDuration)
            if costStats.isEmpty == false {
                SectionHeaderView(title: "Cost Stats")
                    .padding(.top, 2)

                ForEach(costStats, id: \.currencyCode) { stat in
                    CardRowContainer {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(stat.currencyCode)
                                .font(.headline)

                            Text("Avg cost per battery: \(currencyText(amount: stat.averageCostPerBattery, currencyCode: stat.currencyCode))")
                                .font(.subheadline)

                            Text("Cost per day: \(costPerDayText(for: stat))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsAddPackSheet) {
            AddBatteryPackSheet(
                existingPacks: packs,
                previousPack: packs.last,
                onSave: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
                    try? batteryPackService.createBatteryPack(
                        batteryType: batteryType,
                        purchaseDate: purchaseDate,
                        batteriesPerPack: batteriesPerPack,
                        numberOfPacks: numberOfPacks,
                        priceAmount: priceAmount,
                        currencyCode: currencyCode,
                        brand: brand,
                        context: context
                    )
                    showsAddPackSheet = false
                },
                onCancel: {
                    showsAddPackSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .alert("Delete Battery Pack?", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) {
                if let packPendingDelete {
                    try? batteryPackService.deleteBatteryPack(packPendingDelete, context: context)
                }
                packPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                packPendingDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { packPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    packPendingDelete = nil
                }
            }
        )
    }

    private func priceText(for pack: BatteryPack) -> String? {
        guard let amount = pack.priceAmount, let currency = pack.currencyCode else { return nil }
        return "Price: \(currencyText(amount: amount, currencyCode: currency))"
    }

    private func pricePerBatteryText(for pack: BatteryPack) -> String? {
        guard let amount = pack.priceAmount, let currency = pack.currencyCode else { return nil }
        guard pack.quantityPurchased > 0 else { return nil }
        let pricePerBattery = amount / Decimal(pack.quantityPurchased)
        return currencyText(amount: pricePerBattery, currencyCode: currency)
    }

    private func costPerDayText(for stat: BatteryPackCostStat) -> String {
        guard let costPerDay = stat.costPerDay else { return "Not enough data" }
        return currencyText(amount: costPerDay, currencyCode: stat.currencyCode)
    }

    private func currencyText(amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "\(currencyCode) \(number.stringValue)"
    }
}

struct AddBatteryPackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var batteryType: String = ""
    @State private var brand: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var batteriesPerPack: Int = 6
    @State private var numberOfPacks: Int = 1
    @State private var priceText: String = ""
    @State private var currencyCode: String = "USD"

    let existingPacks: [BatteryPack]
    let previousPack: BatteryPack?
    let onSave: (String, String?, Date, Int, Int, Decimal?, String?) -> Void
    let onCancel: () -> Void
    var wrapsInNavigationStack: Bool = true

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack {
                    formContent
                }
            } else {
                formContent
            }
        }
    }

    private var formContent: some View {
        Form {
            Section("Pack") {
                HStack(spacing: 8) {
                    TextField("Battery type (e.g. 312)", text: $batteryType)
                    if batteryTypeSuggestions.isEmpty == false {
                        Menu("Type") {
                            ForEach(batteryTypeSuggestions, id: \.self) { suggestion in
                                Button(suggestion) { batteryType = suggestion }
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Company / brand", text: $brand)
                    if brandSuggestions.isEmpty == false {
                        Menu("Brand") {
                            ForEach(brandSuggestions, id: \.self) { suggestion in
                                Button(suggestion) { brand = suggestion }
                            }
                        }
                    }
                }
                DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                Stepper("Batteries per pack: \(batteriesPerPack)", value: $batteriesPerPack, in: 1...100)
                Stepper("Number of packs: \(numberOfPacks)", value: $numberOfPacks, in: 1...100)
                if let previousPack {
                    Button("Copy Previous Pack") {
                        applyPreviousPack(previousPack)
                    }
                }
            }

            Section("Optional Price") {
                HStack(spacing: 8) {
                    TextField("Price amount", text: $priceText)
                        .keyboardType(.decimalPad)
                    if priceSuggestions.isEmpty == false {
                        Menu("Price") {
                            ForEach(priceSuggestions, id: \.self) { suggestion in
                                Button(suggestion) { priceText = suggestion }
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Currency code", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                    if currencySuggestions.isEmpty == false {
                        Menu("Currency") {
                            ForEach(currencySuggestions, id: \.self) { suggestion in
                                Button(suggestion) { currencyCode = suggestion }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Battery Pack")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave(
                        batteryType.trimmingCharacters(in: .whitespacesAndNewlines),
                        normalizedBrand,
                        purchaseDate,
                        batteriesPerPack,
                        numberOfPacks,
                        decimalValue(from: priceText),
                        normalizedCurrencyCode
                    )
                    dismiss()
                }
                .disabled(batteryType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var normalizedCurrencyCode: String? {
        let trimmed = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedBrand: String? {
        let trimmed = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var batteryTypeSuggestions: [String] {
        uniqueStrings(existingPacks.map(\.batteryType))
    }

    private var brandSuggestions: [String] {
        uniqueStrings(existingPacks.compactMap(\.brand))
    }

    private var currencySuggestions: [String] {
        uniqueStrings(existingPacks.compactMap(\.currencyCode).map { $0.uppercased() })
    }

    private var priceSuggestions: [String] {
        uniqueStrings(existingPacks.compactMap { pack in
            guard let amount = pack.priceAmount else { return nil }
            return NSDecimalNumber(decimal: amount).stringValue
        })
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []
        for value in values.reversed() {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            guard seen.contains(trimmed) == false else { continue }
            seen.insert(trimmed)
            output.append(trimmed)
        }
        return output
    }

    private func applyPreviousPack(_ pack: BatteryPack) {
        batteryType = pack.batteryType
        brand = pack.brand ?? ""
        batteriesPerPack = max(1, pack.batteriesPerPack)
        numberOfPacks = max(1, pack.numberOfPacks)
        priceText = pack.priceAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        currencyCode = pack.currencyCode ?? currencyCode
    }

    private func decimalValue(from input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return Decimal(string: trimmed)
    }
}
