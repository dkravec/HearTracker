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
    @State private var showsAddHearingAidSheet: Bool = false
    @State private var showsLogAidPicker: Bool = false
    @State private var showsPackAidPicker: Bool = false
    @State private var addPackAid: HearingAid?
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
                                        let aidPacks = packsForAid(aid.id)
                                        let costStats = batteryPackService.costStatsByCurrency(
                                            from: aidPacks,
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
                                        beginPackFlow()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        } else {
                            ForEach(packs) { pack in
                                CardRowContainer {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(pack.hearingAid?.name ?? "Unknown Aid")
                                                .font(.headline)
                                            Spacer(minLength: 8)
                                            Text("\(pack.quantityRemaining)/\(pack.quantityPurchased) left")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }

                                        Text("Type: \(pack.batteryType)")
                                            .font(.subheadline)

                                        if let brand = pack.brand, brand.isEmpty == false {
                                            Text("Brand: \(brand)")
                                                .font(.subheadline)
                                        }

                                        Text("Purchased \(pack.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        if let amount = pack.priceAmount, let code = pack.currencyCode {
                                            Text("Price: \(currencyText(amount: amount, currencyCode: code))")
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
                    Button("Add") {
                        showsAddActions = true
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
        .confirmationDialog("Add", isPresented: $showsAddActions, titleVisibility: .visible) {
            Button("Battery Log") {
                beginLogFlow()
            }
            .disabled(activeAids.isEmpty)

            Button("Pack") {
                beginPackFlow()
            }
            .disabled(activeAids.isEmpty)

            Button("Hearing Aid") {
                showsAddHearingAidSheet = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Log Battery For", isPresented: $showsLogAidPicker, titleVisibility: .visible) {
            ForEach(activeAids) { aid in
                Button(aid.name) {
                    viewModel.beginLog(for: aid)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Add Pack For", isPresented: $showsPackAidPicker, titleVisibility: .visible) {
            ForEach(activeAids) { aid in
                Button(aid.name) {
                    addPackAid = aid
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showsAddHearingAidSheet) {
            NavigationStack {
                AddHearingAidView()
                    .appBackground()
            }
        }
        .sheet(item: $viewModel.logTargetAid) { aid in
            BatteryLogSheet(
                note: $viewModel.logNote,
                timestamp: $viewModel.logTimestamp,
                onSave: { timestamp, note in
                    viewModel.saveLog(for: aid, timestamp: timestamp, note: note, context: context)
                },
                onSaveWithoutNote: { timestamp in
                    viewModel.saveLogWithoutNote(for: aid, timestamp: timestamp, context: context)
                },
                onCancel: {
                    viewModel.endLog()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .sheet(item: $addPackAid) { aid in
            AddBatteryPackSheet(
                existingPacks: packsForAid(aid.id),
                previousPack: packsForAid(aid.id).last,
                onSave: { batteryType, brand, purchaseDate, quantityPurchased, priceAmount, currencyCode in
                    try? batteryPackService.createBatteryPack(
                        for: aid,
                        batteryType: batteryType,
                        purchaseDate: purchaseDate,
                        quantityPurchased: quantityPurchased,
                        priceAmount: priceAmount,
                        currencyCode: currencyCode,
                        brand: brand,
                        context: context
                    )
                    addPackAid = nil
                },
                onCancel: {
                    addPackAid = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
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

    private func beginLogFlow() {
        if activeAids.count == 1, let onlyAid = activeAids.first {
            viewModel.beginLog(for: onlyAid)
            return
        }
        showsLogAidPicker = true
    }

    private func beginPackFlow() {
        if activeAids.count == 1, let onlyAid = activeAids.first {
            addPackAid = onlyAid
            return
        }
        showsPackAidPicker = true
    }

    private func packsForAid(_ hearingAidId: UUID) -> [BatteryPack] {
        packs
            .filter { $0.hearingAid?.id == hearingAidId }
            .sorted { $0.purchaseDate < $1.purchaseDate }
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
