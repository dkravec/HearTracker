//
//  HearingAidListView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData

struct HearingAidListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]
    @Query(sort: \BatteryPack.purchaseDate, order: .reverse) private var packs: [BatteryPack]

    @StateObject private var viewModel = HearingAidListViewModel()
    private let statsService = BatteryStatsService()
    private let batteryPackService = BatteryPackService()
    private let durationFormatter = BatteryDurationFormatter()
    private static let statsWindowSize: Int = 10

    @State private var showsAddActions: Bool = false
    @State private var packPendingDelete: BatteryPack?

    private var activeAids: [HearingAid] {
        viewModel.activeAids(from: hearingAids)
    }

    private var retiredAids: [HearingAid] {
        viewModel.retiredAids(from: hearingAids)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if viewModel.showsInventoryWarning {
                            CardRowContainer {
                                HStack(alignment: .top, spacing: 10) {
                                    Label("No battery pack inventory found. Log saved without consuming inventory.", systemImage: "exclamationmark.triangle")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 8)
                                    Button("Dismiss") {
                                        viewModel.dismissInventoryWarning()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        if activeAids.isEmpty == false {
                            SectionHeaderView(title: "Battery Stats")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(activeAids) { aid in
                                        let snapshot = statsService.statsSnapshot(
                                            for: aid.id,
                                            windowSize: Self.statsWindowSize,
                                            context: context
                                        )
                                        let costStats = batteryPackService.costStatsByCurrency(
                                            from: packs,
                                            averageDuration: snapshot.avgDuration
                                        )
                                        HomeBatteryStatsCard(
                                            aidName: aid.name,
                                            snapshot: snapshot,
                                            durationFormatter: durationFormatter,
                                            costPerDaySummary: costPerDaySummary(from: costStats)
                                        )
                                    }
                                }
                                .padding(.horizontal, 1)
                                .padding(.vertical, 2)
                            }
                        }

                        if activeAids.isEmpty {
                            EmptyStateView(
                                title: "No Hearing Aids",
                                systemImage: "ear",
                                message: "Add a hearing aid to start tracking battery changes."
                            )
                        } else {
                            SectionHeaderView(title: "Hearing Aids")
                        }

                        ForEach(activeAids) { aid in
                            HearingAidCardRow(
                                aid: aid,
                                onLogTapped: { viewModel.beginLog(for: aid) }
                            )
                        }

                        SectionHeaderView(title: "Battery Packs")
                            .padding(.top, 8)

                        if packs.isEmpty {
                            CardRowContainer {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("No Battery Packs")
                                        .font(.headline)
                                    Text("Add a battery pack to track inventory and cost.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button("Add Pack") {
                                        showsAddActions = true
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

                                        Text("Purchased \(pack.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Text("Batteries per pack: \(pack.batteriesPerPack)")
                                            .font(.subheadline)
                                        Text("Number of packs: \(pack.numberOfPacks)")
                                            .font(.subheadline)

                                        if let amount = pack.priceAmount, let code = pack.currencyCode {
                                            Text("Price: \(currencyText(amount: amount, currencyCode: code))")
                                                .font(.subheadline)
                                            if let pricePerBattery = pricePerBatteryText(for: pack, currencyCode: code) {
                                                Text("Price per battery: \(pricePerBattery)")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
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

                        if viewModel.showsRetired, !retiredAids.isEmpty {
                            SectionHeaderView(title: "Retired")
                                .padding(.top, 8)

                            ForEach(retiredAids) { aid in
                                HearingAidCardRow(
                                    aid: aid,
                                    onLogTapped: { viewModel.beginLog(for: aid) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.clear)
            }
            .navigationTitle("Hearing Aids")
            .navigationDestination(for: HearingAid.self) { aid in
                HearingAidDetailView(aid: aid)
            }
            .navigationDestination(for: BatteryLogRoute.self) { route in
                BatteryLogDetailContainer(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsAddActions = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !retiredAids.isEmpty {
                        Button(viewModel.showsRetired ? "Hide Retired" : "Show Retired") {
                            viewModel.showsRetired.toggle()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsAddActions) {
            AddEntryChoiceSheet(
                activeAids: activeAids,
                availablePacks: availablePacks,
                packs: Array(packs),
                defaultAidId: viewModel.aidNextToDie(from: activeAids, context: context)?.id ?? activeAids.first?.id,
                onSaveBatteryLog: { aid, timestamp, note, packId in
                    viewModel.selectedPackId = packId
                    viewModel.saveLog(for: aid, timestamp: timestamp, note: note, context: context)
                },
                onSavePack: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
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
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .sheet(isPresented: $viewModel.showsLogSheet) {
            if viewModel.resolvedAid(from: hearingAids) != nil {
                BatteryLogSheet(
                    note: $viewModel.logNote,
                    timestamp: $viewModel.logTimestamp,
                    selectedPackId: $viewModel.selectedPackId,
                    availablePacks: availablePacks,
                    onSave: { timestamp, note in
                        if let currentAid = viewModel.resolvedAid(from: hearingAids) {
                            viewModel.saveLog(for: currentAid, timestamp: timestamp, note: note, context: context)
                        }
                    },
                    onCancel: {
                        viewModel.endLog()
                    },
                    activeAids: activeAids,
                    selectedAidId: $viewModel.selectedLogAidId
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .appBackground()
            }
        }
        .alert("Delete Battery Pack?", isPresented: deletePackAlertBinding) {
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

    private var deletePackAlertBinding: Binding<Bool> {
        Binding(
            get: { packPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    packPendingDelete = nil
                }
            }
        )
    }

    private func costPerDaySummary(from costStats: [BatteryPackCostStat]) -> String {
        guard costStats.isEmpty == false else { return "Not enough data" }

        let pieces = costStats.compactMap { stat -> String? in
            guard let costPerDay = stat.costPerDay else { return nil }
            return "\(stat.currencyCode) \(currencyText(amount: costPerDay, currencyCode: stat.currencyCode))/day"
        }

        if pieces.isEmpty { return "Not enough data" }
        if pieces.count == 1 { return pieces[0] }
        return "\(pieces[0]) +\(pieces.count - 1)"
    }

    private func currencyText(amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? number.stringValue
    }

    private func pricePerBatteryText(for pack: BatteryPack, currencyCode: String) -> String? {
        guard let amount = pack.priceAmount, pack.quantityPurchased > 0 else { return nil }
        let pricePerBattery = amount / Decimal(pack.quantityPurchased)
        return currencyText(amount: pricePerBattery, currencyCode: currencyCode)
    }

    private var availablePacks: [BatteryPack] {
        packs.filter { $0.quantityRemaining > 0 }
    }
}

private struct HomeBatteryStatsCard: View {
    let aidName: String
    let snapshot: BatteryStatsSnapshot
    let durationFormatter: BatteryDurationFormatter
    let costPerDaySummary: String

    var body: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "battery.75")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(aidName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text("\(snapshot.sampleCount) samples")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }

                statRow(
                    title: "Current / Predicted",
                    value: "\(durationFormatter.optionalDaysText(from: snapshot.currentAge) ?? "n/a") • \(snapshot.predictedDeath.map { durationFormatter.relativeDateText(from: $0) } ?? "n/a")",
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                )

                statRow(
                    title: "Average",
                    value: durationFormatter.optionalDaysText(from: snapshot.avgDuration) ?? "Not enough data",
                    icon: "chart.bar"
                )

                statRow(
                    title: "Cost / day",
                    value: costPerDaySummary,
                    icon: "dollarsign.circle"
                )
            }
            .frame(width: 245, height: 200, alignment: .topLeading)
        }
    }

    private func statRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct HearingAidCardRow: View {
    let aid: HearingAid
    let onLogTapped: () -> Void

    var body: some View {
        NavigationLink(value: aid) {
            CardRowContainer {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(aid.name)
                            .font(.headline)

                        if let model = aid.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                            Text(model)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let batteryType = aid.batteryType?.trimmingCharacters(in: .whitespacesAndNewlines), !batteryType.isEmpty {
                            Text("Type \(batteryType)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("\((aid.logs ?? []).count) changes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button("Log") {
                        onLogTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Log battery change for \(aid.name)")
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AddEntryChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let activeAids: [HearingAid]
    let availablePacks: [BatteryPack]
    let packs: [BatteryPack]
    let defaultAidId: UUID?
    let onSaveBatteryLog: (HearingAid, Date, String?, UUID?) -> Void
    let onSavePack: (String, String?, Date, Int, Int, Decimal?, String?) -> Void

    @State private var logNote: String = ""
    @State private var logTimestamp: Date = Date()
    @State private var selectedPackId: UUID?
    @State private var selectedAidId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if activeAids.isEmpty == false {
                        NavigationLink {
                            BatteryLogSheet(
                                note: $logNote,
                                timestamp: $logTimestamp,
                                selectedPackId: $selectedPackId,
                                availablePacks: availablePacks,
                                onSave: { timestamp, note in
                                    if let aid = activeAids.first(where: { $0.id == selectedAidId }) ?? activeAids.first {
                                        onSaveBatteryLog(aid, timestamp, note, selectedPackId)
                                    }
                                    dismiss()
                                },
                                onCancel: { dismiss() },
                                activeAids: activeAids,
                                selectedAidId: $selectedAidId,
                                wrapsInNavigationStack: false
                            )
                        } label: {
                            AddItemActionRowLabel(title: "Battery Log", subtitle: batteryLogSubtitle, systemImage: "bolt.batteryblock")
                        }
                        .buttonStyle(.plain)
                        .onAppear { selectedAidId = defaultAidId }
                    } else {
                        AddItemActionRowLabel(title: "Battery Log", subtitle: "Add a hearing aid first", systemImage: "bolt.batteryblock", isDisabled: true)
                    }

                    NavigationLink {
                        AddBatteryPackSheet(
                            existingPacks: packs.sorted { $0.purchaseDate < $1.purchaseDate },
                            previousPack: packs.sorted { $0.purchaseDate < $1.purchaseDate }.last,
                            onSave: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
                                onSavePack(batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode)
                                dismiss()
                            },
                            onCancel: { dismiss() },
                            wrapsInNavigationStack: false
                        )
                    } label: {
                        AddItemActionRowLabel(title: "Pack", subtitle: "Add battery inventory", systemImage: "shippingbox")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AddHearingAidView()
                    } label: {
                        AddItemActionRowLabel(title: "Hearing Aid", subtitle: "Add a new device", systemImage: "ear")
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var batteryLogSubtitle: String {
        if activeAids.count == 1, let onlyAid = activeAids.first {
            return "Quick log for \(onlyAid.name)"
        }
        return "Log a battery change"
    }
}

private struct AddItemActionRowLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(isDisabled ? .secondary : .primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .opacity(isDisabled ? 0.55 : 1)
    }
}
