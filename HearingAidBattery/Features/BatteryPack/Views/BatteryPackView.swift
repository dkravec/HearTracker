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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                BatteryPackSectionView(
                    averageDuration: averageDuration
                )
            }
            .screenContentPadding()
        }
        .navigationTitle("Battery Packs")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
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

struct BatteryPackSectionView: View {
    @Environment(\.modelContext) private var context

    let averageDuration: TimeInterval?
    @Query private var packs: [BatteryPack]

    @State private var showsAddPackSheet: Bool = false
    @State private var packPendingDelete: BatteryPack?
    @State private var packPendingEdit: BatteryPack?
    @State private var packPendingUsage: BatteryPack?
    @State private var errorMessage: String?

    private let batteryPackService = BatteryPackService()

    init(averageDuration: TimeInterval?) {
        self.averageDuration = averageDuration
        let activeSpaceId = SpaceService.activeSpaceIdForQueries
        _packs = Query(
            filter: #Predicate<BatteryPack> { $0.spaceId == activeSpaceId },
            sort: \BatteryPack.purchaseDate,
            order: .forward
        )
    }

    private var activePacks: [BatteryPack] {
        packs.filter { $0.quantityRemaining > 0 && $0.isDone == false }
    }

    private var doneOrEmptyPacks: [BatteryPack] {
        packs.filter { $0.quantityRemaining == 0 || $0.isDone }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Battery Packs")
            if packs.isEmpty {
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No Battery Packs")
                            .font(.headline)
                        Text("Add a battery pack to track inventory and cost.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                if activePacks.isEmpty {
                    CardRowContainer {
                        Text("No active packs. Done/empty packs are shown below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(activePacks) { pack in
                        packRow(for: pack)
                    }
                }

                if doneOrEmptyPacks.isEmpty == false {
                    SectionHeaderView(title: "Done / Empty Packs")
                        .padding(.top, 4)
                    ForEach(doneOrEmptyPacks) { pack in
                        packRow(for: pack)
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

                            Text("Avg cost per battery: \(CurrencyFormatter.shared.format(stat.averageCostPerBattery, currencyCode: stat.currencyCode))")
                                .font(.subheadline)

                            Text("Cost per day: \(formattedCostPerDay(for: stat))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showsAddPackSheet = true
                } label: {
                    Label("Add Pack", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showsAddPackSheet) {
            AddBatteryPackSheet(
                existingPacks: packs,
                previousPack: packs.last,
                title: "Add Battery Pack",
                saveButtonTitle: "Save",
                onSave: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
                    try batteryPackService.createBatteryPack(
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
        .sheet(item: $packPendingEdit) { pack in
            EditBatteryPackSheet(
                pack: pack,
                existingPacks: packs,
                batteryPackService: batteryPackService,
                errorMessage: $errorMessage,
                onClose: {
                    packPendingEdit = nil
                }
            )
        }
        .sheet(item: $packPendingUsage) { pack in
            UseBatteriesSheet(
                pack: pack,
                onSave: { count, note, timestamp in
                    do {
                        try batteryPackService.useBatteries(
                            count,
                            note: note,
                            timestamp: timestamp,
                            from: pack,
                            context: context
                        )
                        packPendingUsage = nil
                    } catch {
                        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                },
                onCancel: {
                    packPendingUsage = nil
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .alert("Delete Battery Pack?", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) {
                if let packPendingDelete {
                    do {
                        try batteryPackService.deletePack(packPendingDelete, context: context)
                    } catch {
                        errorMessage = "Could not delete battery pack."
                    }
                }
                packPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                packPendingDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .errorAlert(title: "Unable to Complete Action", message: $errorMessage)
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

    @ViewBuilder
    private func packRow(for pack: BatteryPack) -> some View {
        NavigableCardRow {
            BatteryPackDetailView(
                pack: pack,
                existingPacks: packs,
                averageDuration: averageDuration
            )
        } content: {
            BatteryPackCardBody(pack: pack)
        }
        .contextMenu {
            Button("Edit Pack") {
                packPendingEdit = pack
            }
            if pack.isDone {
                Button("Mark as Active") {
                    markPackAsActive(pack)
                }
            } else {
                Button("Use Batteries…") {
                    packPendingUsage = pack
                }
                Button("Mark Done (Empty)") {
                    markPackDone(pack, markLost: false)
                }
                Button("Mark Lost") {
                    markPackDone(pack, markLost: true)
                }
            }
            Button("Delete Pack", role: .destructive) {
                packPendingDelete = pack
            }
        }
    }

    private func markPackDone(_ pack: BatteryPack, markLost: Bool) {
        do {
            try batteryPackService.markPackDone(pack, markLost: markLost, context: context)
        } catch {
            errorMessage = markLost ? "Could not mark pack as lost." : "Could not mark pack as done."
        }
    }

    private func markPackAsActive(_ pack: BatteryPack) {
        do {
            try batteryPackService.unmarkPackDone(pack, context: context)
        } catch {
            errorMessage = "Could not mark pack as active."
        }
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
    @State private var currencyCode: String = CurrencyFormatter.localeCurrencyCode
    @State private var customCurrencyCode: String = ""
    @State private var errorMessage: String?

    private static let otherSentinel = "__OTHER__"

    let existingPacks: [BatteryPack]
    let previousPack: BatteryPack?
    let title: String
    let saveButtonTitle: String
    let initialBatteryType: String
    let initialBrand: String
    let initialPurchaseDate: Date
    let initialBatteriesPerPack: Int
    let initialNumberOfPacks: Int
    let initialPriceText: String
    let initialCurrencyCode: String
    let onSave: (String, String?, Date, Int, Int, Decimal?, String?) throws -> Void
    let onCancel: () -> Void
    var wrapsInNavigationStack: Bool = true

    init(
        existingPacks: [BatteryPack],
        previousPack: BatteryPack?,
        title: String = "Add Battery Pack",
        saveButtonTitle: String = "Save",
        initialBatteryType: String = "",
        initialBrand: String = "",
        initialPurchaseDate: Date = Date(),
        initialBatteriesPerPack: Int = 6,
        initialNumberOfPacks: Int = 1,
        initialPriceText: String = "",
        initialCurrencyCode: String = CurrencyFormatter.localeCurrencyCode,
        onSave: @escaping (String, String?, Date, Int, Int, Decimal?, String?) throws -> Void,
        onCancel: @escaping () -> Void,
        wrapsInNavigationStack: Bool = true
    ) {
        self.existingPacks = existingPacks
        self.previousPack = previousPack
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.initialBatteryType = initialBatteryType
        self.initialBrand = initialBrand
        self.initialPurchaseDate = initialPurchaseDate
        self.initialBatteriesPerPack = initialBatteriesPerPack
        self.initialNumberOfPacks = initialNumberOfPacks
        self.initialPriceText = initialPriceText
        self.initialCurrencyCode = initialCurrencyCode
        self.onSave = onSave
        self.onCancel = onCancel
        self.wrapsInNavigationStack = wrapsInNavigationStack
    }

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
        .onAppear {
            batteryType = initialBatteryType
            brand = initialBrand
            purchaseDate = initialPurchaseDate
            batteriesPerPack = initialBatteriesPerPack
            numberOfPacks = initialNumberOfPacks
            priceText = initialPriceText
            currencyCode = initialCurrencyCode
        }
    }

    private var formContent: some View {
        Form {
            Section("Pack") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Battery Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 312", text: $batteryType)
                    if batteryTypeSuggestions.isEmpty == false {
                        Menu("Type") {
                            ForEach(batteryTypeSuggestions, id: \.self) { suggestion in
                                Button(suggestion) { batteryType = suggestion }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Brand")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Company or brand name", text: $brand)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Price Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 12.99", text: $priceText)
                        .keyboardType(.decimalPad)
                    if priceSuggestions.isEmpty == false {
                        Menu("Price") {
                            ForEach(priceSuggestions, id: \.self) { suggestion in
                                Button(suggestion) { priceText = suggestion }
                            }
                        }
                    }
                }
                Picker("Currency", selection: $currencyCode) {
                    ForEach(availableCurrencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                    Text("Other…").tag(Self.otherSentinel)
                }
                if currencyCode == Self.otherSentinel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Custom Currency Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. ZAR", text: $customCurrencyCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(saveButtonTitle) {
                    do {
                        try onSave(
                            batteryType.trimmingCharacters(in: .whitespacesAndNewlines),
                            normalizedBrand,
                            purchaseDate,
                            batteriesPerPack,
                            numberOfPacks,
                            decimalValue(from: priceText),
                            normalizedCurrencyCode
                        )
                        dismiss()
                    } catch {
                        errorMessage = "Could not save battery pack."
                    }
                }
                .disabled(batteryType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .errorAlert(title: "Unable to Save Battery Pack", message: $errorMessage)
    }

    private var effectiveCurrencyCode: String {
        currencyCode == Self.otherSentinel ? customCurrencyCode : currencyCode
    }

    private var normalizedCurrencyCode: String? {
        let trimmed = effectiveCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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

    private var availableCurrencyCodes: [String] {
        var codes = CurrencyFormatter.commonCurrencyCodes
        let existing = uniqueStrings(existingPacks.compactMap(\.currencyCode).map { $0.uppercased() })
        for code in existing.reversed() {
            if !codes.contains(code) {
                codes.insert(code, at: 0)
            }
        }
        return codes
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
        CurrencyFormatter.decimalFromInput(input)
    }
}

struct BatteryPackCardBody: View {
    let pack: BatteryPack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pack.batteryType)
                    .font(.headline)
                Spacer(minLength: 8)
                Text("\(pack.quantityRemaining)/\(pack.quantityPurchased) left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if pack.isDone {
                Text(pack.isMarkedLost ? "Marked done (lost)" : "Marked done (empty)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(pack.isMarkedLost ? .orange : .secondary)
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

            if let amount = pack.priceAmount, let code = pack.currencyCode {
                Text("Price: \(CurrencyFormatter.shared.format(amount, currencyCode: code))")
                    .font(.subheadline)
            }

            if let ppb = CurrencyFormatter.shared.pricePerBattery(priceAmount: pack.priceAmount, quantityPurchased: pack.quantityPurchased, currencyCode: pack.currencyCode) {
                Text("Price per battery: \(ppb)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BatteryPackDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pack: BatteryPack
    let existingPacks: [BatteryPack]
    let averageDuration: TimeInterval?

    @State private var showsEditSheet: Bool = false
    @State private var showsDeleteConfirm: Bool = false
    @State private var errorMessage: String?
    @State private var lotRenderNonce: UUID = UUID()

    private let batteryPackService = BatteryPackService()

    private var availableLots: [BatteryPackLot] {
        _ = lotRenderNonce
        return (pack.lots ?? [])
            .filter { $0.isMarkedLost == false && $0.quantityRemaining > 0 }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    private var openAvailableLots: [BatteryPackLot] {
        availableLots
            .filter { $0.openedAt != nil }
            .sorted {
                guard let left = $0.openedAt, let right = $1.openedAt else { return false }
                return left < right
            }
    }

    private var unopenedAvailableLots: [BatteryPackLot] {
        availableLots
            .filter { $0.openedAt == nil }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Battery Pack")
                CardRowContainer {
                    BatteryPackCardBody(pack: pack)
                }

                if let stat = batteryPackService
                    .costStatsByCurrency(from: [pack], averageDuration: averageDuration)
                    .first {
                    SectionHeaderView(title: "Cost")
                    CardRowContainer {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Avg cost per battery: \(CurrencyFormatter.shared.format(stat.averageCostPerBattery, currencyCode: stat.currencyCode))")
                                .font(.subheadline)
                            Text("Cost per day: \(formattedCostPerDay(for: stat))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if pack.isDone == false, openAvailableLots.isEmpty == false {
                    SectionHeaderView(title: "Opened Packs")
                    ForEach(openAvailableLots, id: \.id) { lot in
                        LotRowView(
                            lot: lot,
                            isOpened: true,
                            onConsume: { adjustLot(lot, mode: .consume) },
                            onRestore: { adjustLot(lot, mode: .restore) }
                        )
                        .id("\(lot.id)-\(lotRenderNonce)")
                    }
                }

                if pack.isDone == false, unopenedAvailableLots.isEmpty == false {
                    SectionHeaderView(title: "Unopened Packs")
                    ForEach(unopenedAvailableLots, id: \.id) { lot in
                        LotRowView(
                            lot: lot,
                            isOpened: false,
                            onConsume: { adjustLot(lot, mode: .consume) },
                            onRestore: { adjustLot(lot, mode: .restore) }
                        )
                        .id("\(lot.id)-\(lotRenderNonce)")
                    }
                }

                CardRowContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pack Status")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if pack.isDone {
                            HStack(spacing: 8) {
                                Text(pack.isMarkedLost ? "This pack is marked lost." : "This pack is marked done.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Button("Mark Active") {
                                    markPackAsActive()
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Button("Mark Done (Empty)") {
                                    markPackDone(markLost: false)
                                }
                                .buttonStyle(.bordered)

                                Button("Mark Lost") {
                                    markPackDone(markLost: true)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Button("Delete Pack", role: .destructive) {
                            showsDeleteConfirm = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("Pack Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showsEditSheet = true
                }
            }
        }
        .appBackground()
        .sheet(isPresented: $showsEditSheet) {
            EditBatteryPackSheet(
                pack: pack,
                existingPacks: existingPacks,
                batteryPackService: batteryPackService,
                errorMessage: $errorMessage,
                onClose: {
                    showsEditSheet = false
                }
            )
        }
        .alert("Delete Battery Pack?", isPresented: $showsDeleteConfirm) {
            Button("Delete", role: .destructive) {
                do {
                    try batteryPackService.deletePack(pack, context: context)
                    dismiss()
                } catch {
                    errorMessage = "Could not delete battery pack."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .errorAlert(title: "Unable to Complete Action", message: $errorMessage)
        .onAppear {
            pack.ensureLotsIfNeeded()
        }
    }

    private func markPackDone(markLost: Bool) {
        do {
            try batteryPackService.markPackDone(pack, markLost: markLost, context: context)
        } catch {
            errorMessage = markLost ? "Could not mark pack as lost." : "Could not mark pack as done."
        }
    }

    private func markPackAsActive() {
        do {
            try batteryPackService.unmarkPackDone(pack, context: context)
        } catch {
            errorMessage = "Could not mark pack as active."
        }
    }

    private enum LotAdjustMode {
        case consume
        case restore
    }

    private func adjustLot(_ lot: BatteryPackLot, mode: LotAdjustMode) {
        do {
            pack.ensureLotsIfNeeded()
            switch mode {
            case .consume:
                let consumed = pack.consumeFromSpecificLot(lotId: lot.id, count: 1)
                var usedFallback = false
                if consumed == 0, lot.quantityRemaining > 0 {
                    lot.quantityRemaining -= 1
                    if lot.openedAt == nil {
                        lot.openedAt = Date()
                    }
                    pack.syncTotalsFromLots()
                    usedFallback = true
                }
                guard consumed == 1 || usedFallback else {
                    throw BatteryPackServiceError.usageExceedsAvailable
                }
            case .restore:
                let restored = pack.restoreToSpecificLot(lotId: lot.id, count: 1)
                if restored == 0, lot.quantityRemaining < lot.quantityInitial {
                    lot.quantityRemaining += 1
                    if lot.quantityRemaining >= lot.quantityInitial {
                        lot.openedAt = nil
                    }
                    pack.syncTotalsFromLots()
                }
            }
            try context.save()
            lotRenderNonce = UUID()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct LotRowView: View {
    let lot: BatteryPackLot
    let isOpened: Bool
    let onConsume: () -> Void
    let onRestore: () -> Void

    var body: some View {
        CardRowContainer {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pack \(lot.sortIndex + 1)")
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    onConsume()
                } label: {
                    Image(systemName: "minus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .disabled(lot.quantityRemaining <= 0)

                Button {
                    onRestore()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(isOpened ? lot.quantityRemaining >= lot.quantityInitial : true)
            }
        }
    }

    private var subtitle: String {
        if let openedAt = lot.openedAt {
            return "opened \(openedAt.formatted(date: .abbreviated, time: .shortened)) • \(lot.quantityRemaining) left"
        }
        return "unopened • \(lot.quantityRemaining) left"
    }
}

private struct EditBatteryPackSheet: View {
    @Environment(\.modelContext) private var context

    let pack: BatteryPack
    let existingPacks: [BatteryPack]
    let batteryPackService: BatteryPackService
    @Binding var errorMessage: String?
    let onClose: () -> Void

    var body: some View {
        AddBatteryPackSheet(
            existingPacks: existingPacks,
            previousPack: nil,
            title: "Edit Battery Pack",
            saveButtonTitle: "Save",
            initialBatteryType: pack.batteryType,
            initialBrand: pack.brand ?? "",
            initialPurchaseDate: pack.purchaseDate,
            initialBatteriesPerPack: max(1, pack.batteriesPerPack),
            initialNumberOfPacks: max(1, pack.numberOfPacks),
            initialPriceText: pack.priceAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
            initialCurrencyCode: pack.currencyCode ?? CurrencyFormatter.localeCurrencyCode,
            onSave: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
                try batteryPackService.updatePack(
                    pack,
                    batteryType: batteryType,
                    purchaseDate: purchaseDate,
                    batteriesPerPack: batteriesPerPack,
                    numberOfPacks: numberOfPacks,
                    priceAmount: priceAmount,
                    currencyCode: currencyCode,
                    brand: brand,
                    retailer: pack.retailer,
                    note: pack.note,
                    context: context
                )
                onClose()
            },
            onCancel: {
                onClose()
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .appBackground()
    }
}

private func formattedCostPerDay(for stat: BatteryPackCostStat) -> String {
    guard let costPerDay = stat.costPerDay else { return "Not enough data" }
    return CurrencyFormatter.shared.format(costPerDay, currencyCode: stat.currencyCode)
}

struct UseBatteriesSheet: View {
    @State private var countUsed: Int = 1
    @State private var timestamp: Date = Date()
    @State private var note: String = ""

    let pack: BatteryPack
    let onSave: (Int, String?, Date) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Pack") {
                    Text(pack.batteryType)
                        .font(.headline)
                    Text("Remaining: \(pack.quantityRemaining)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Usage") {
                    Stepper("Batteries used: \(countUsed)", value: $countUsed, in: 1...max(1, pack.quantityRemaining))
                    DatePicker(
                        "Timestamp",
                        selection: $timestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note (Optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Add context for this usage", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Use Batteries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(countUsed, trimmedNote.isEmpty ? nil : trimmedNote, timestamp)
                    }
                    .disabled(pack.quantityRemaining <= 0 || pack.isDone)
                }
            }
        }
    }
}
