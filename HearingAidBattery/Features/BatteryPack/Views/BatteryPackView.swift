//
//  BatteryPackView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI
import SwiftData

struct BatteryPackListView: View {
    let hearingAid: HearingAid
    let averageDuration: TimeInterval?

    var body: some View {
        BatteryPackSectionView(
            hearingAid: hearingAid,
            averageDuration: averageDuration
        )
    }
}

struct BatteryPackView: View {
    let hearingAid: HearingAid
    let averageDuration: TimeInterval?

    var body: some View {
        BatteryPackListView(
            hearingAid: hearingAid,
            averageDuration: averageDuration
        )
    }
}

struct BatteryPackSectionView: View {
    @Environment(\.modelContext) private var context

    let hearingAid: HearingAid
    let averageDuration: TimeInterval?
    @Query private var packs: [BatteryPack]

    @State private var showsAddPackSheet: Bool = false
    @State private var packPendingDelete: BatteryPack?

    private let batteryPackService = BatteryPackService()

    init(hearingAid: HearingAid, averageDuration: TimeInterval?) {
        self.hearingAid = hearingAid
        self.averageDuration = averageDuration
        let hearingAidId = hearingAid.id
        _packs = Query(
            filter: #Predicate<BatteryPack> { $0.hearingAid?.id == hearingAidId },
            sort: \BatteryPack.purchaseDate,
            order: .forward
        )
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

                            Text("Purchased \(pack.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let priceText = priceText(for: pack) {
                                Text(priceText)
                                    .font(.subheadline)
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
                onSave: { batteryType, purchaseDate, quantityPurchased, priceAmount, currencyCode in
                    try? batteryPackService.createBatteryPack(
                        for: hearingAid,
                        batteryType: batteryType,
                        purchaseDate: purchaseDate,
                        quantityPurchased: quantityPurchased,
                        priceAmount: priceAmount,
                        currencyCode: currencyCode,
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

private struct AddBatteryPackSheet: View {
    @State private var batteryType: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var quantityPurchased: Int = 6
    @State private var priceText: String = ""
    @State private var currencyCode: String = "USD"

    let onSave: (String, Date, Int, Decimal?, String?) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Pack") {
                    TextField("Battery type (e.g. 312)", text: $batteryType)
                    DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                    Stepper("Quantity purchased: \(quantityPurchased)", value: $quantityPurchased, in: 1...100)
                }

                Section("Optional Price") {
                    TextField("Price amount", text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField("Currency code", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                }
            }
            .navigationTitle("Add Battery Pack")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(
                            batteryType.trimmingCharacters(in: .whitespacesAndNewlines),
                            purchaseDate,
                            quantityPurchased,
                            decimalValue(from: priceText),
                            normalizedCurrencyCode
                        )
                    }
                    .disabled(batteryType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var normalizedCurrencyCode: String? {
        let trimmed = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func decimalValue(from input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return Decimal(string: trimmed)
    }
}
