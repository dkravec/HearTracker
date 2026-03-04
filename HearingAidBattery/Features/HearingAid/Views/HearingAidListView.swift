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
    @Query private var hearingAids: [HearingAid]
    @Query private var packs: [BatteryPack]
    @Query private var issues: [IssueLog]

    @StateObject private var viewModel = HearingAidListViewModel()
    private let statsService = BatteryStatsService()
    private let batteryPackService = BatteryPackService()
    private let issueLogService = IssueLogService()
    private let durationFormatter = BatteryDurationFormatter()
    private static let statsWindowSize: Int = 10 // change to 0 for all

    @State private var showsAddActions: Bool = false
    @State private var packPendingDelete: BatteryPack?

    init() {
        let activeSpaceId = SpaceService.activeSpaceIdForQueries
        _hearingAids = Query(
            filter: #Predicate<HearingAid> { $0.spaceId == activeSpaceId },
            sort: \HearingAid.createdAt,
            order: .reverse
        )
        _packs = Query(
            filter: #Predicate<BatteryPack> { $0.spaceId == activeSpaceId },
            sort: \BatteryPack.purchaseDate,
            order: .reverse
        )
        _issues = Query(
            filter: #Predicate<IssueLog> { $0.spaceId == activeSpaceId },
            sort: \IssueLog.timestamp,
            order: .reverse
        )
    }

    private var activeAids: [HearingAid] {
        viewModel.activeAids(from: hearingAids)
    }

    private var activePacks: [BatteryPack] {
        packs.filter { $0.quantityRemaining > 0 && $0.isDone == false }
    }

    var body: some View {
        NavigationStack {
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
                                            costStats: costStats,
                                            targetCurrency: mostRecentCurrencyCode
                                        )
                                    }
                                }
                                .padding(.horizontal, 1)
                                .padding(.vertical, 2)
                            }
                        }

                        NavigationLink {
                            HearingAidSectionView()
                        } label: {
                            HStack(spacing: 6) {
                                SectionHeaderView(title: "Hearing Aids")
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        .buttonStyle(.plain)

                        if activeAids.isEmpty {
                            EmptyStateView(
                                title: "No Hearing Aids",
                                systemImage: FeatureSymbols.hearingAid,
                                message: "Add a hearing aid to start tracking battery changes."
                            )
                        } else {
                            ForEach(Array(activeAids.prefix(2))) { aid in
                                HearingAidCardRow(
                                    aid: aid,
                                    onLogTapped: { viewModel.beginLog(for: aid) }
                                )
                            }

                            if activeAids.count > 2 {
                                CardRowContainer {
                                    Text("Showing 2 of \(activeAids.count) hearing aids. Open Hearing Aids for the full list.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        NavigationLink {
                            BatteryPackView(averageDuration: nil)
                        } label: {
                            HStack(spacing: 6) {
                                SectionHeaderView(title: "Battery Packs")
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        .buttonStyle(.plain)

                        if activePacks.isEmpty {
                            EmptyStateView(
                                title: "No Active Battery Packs",
                                systemImage: FeatureSymbols.batteryPack,
                                message: "Add a battery pack to track inventory and cost."
                            )
                        } else {
                            ForEach(activePacks) { pack in
                                NavigableCardRow {
                                    BatteryPackDetailView(
                                        pack: pack,
                                        existingPacks: packs,
                                        averageDuration: nil
                                    )
                                } content: {
                                    BatteryPackCardBody(pack: pack)
                                }
                                .contextMenu {
                                    Button("Delete Pack", role: .destructive) {
                                        packPendingDelete = pack
                                    }
                                }
                            }
                        }

                        NavigationLink {
                            IssueLogView(hearingAids: activeAids)
                        } label: {
                            HStack(spacing: 6) {
                                SectionHeaderView(title: "Issue History")
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        .buttonStyle(.plain)

                        if activeIssues.isEmpty {
                            EmptyStateView(
                                title: "No Issues Logged",
                                systemImage: FeatureSymbols.issue,
                                message: "Log an issue from Add Item."
                            )
                        } else {
                            ForEach(activeIssues) { issue in
                                NavigableCardRow {
                                    IssueLogDetailView(
                                        issue: issue,
                                        hearingAids: activeAids,
                                        issueLogService: issueLogService
                                    )
                                } content: {
                                    IssueCardRow(issue: issue, wrapsInCard: false)
                                }
                            }
                        }

                }
                .screenContentPadding()
            }
            .navigationTitle("HearTracker")
            .navigationDestination(for: BatteryLogRoute.self) { route in
                BatteryLogDetailContainer(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsAddActions = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .appBackground()
        }
        .sheet(isPresented: $showsAddActions) {
            AddEntryChoiceSheet(
                activeAids: activeAids,
                availablePacks: activePacks,
                packs: Array(packs),
                defaultAidId: viewModel.aidNextToDie(from: activeAids, context: context)?.id ?? activeAids.first?.id,
                onSaveBatteryLog: { aid, timestamp, note, packId in
                    viewModel.selectedPackId = packId
                    viewModel.saveLog(for: aid, timestamp: timestamp, note: note, context: context)
                },
                onSavePack: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
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
                    availablePacks: activePacks,
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
                    do {
                        try batteryPackService.deletePack(packPendingDelete, context: context)
                    } catch {
                        viewModel.errorMessage = "Could not delete battery pack."
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
        .errorAlert(title: "Unable to Save", message: $viewModel.errorMessage)
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

    private var activeIssues: [IssueLog] {
        issues.filter { issue in
            guard let aid = issue.hearingAid else { return false }
            return aid.retired == false && issue.isResolved == false
        }
    }

    /// The currency code from the most recently purchased pack, or the user's locale currency.
    private var mostRecentCurrencyCode: String {
        packs.first(where: { $0.currencyCode != nil })?.currencyCode?.uppercased()
            ?? CurrencyFormatter.localeCurrencyCode
    }
}

private struct HomeBatteryStatsCard: View {
    let aidName: String
    let snapshot: BatteryStatsSnapshot
    let durationFormatter: BatteryDurationFormatter
    let costStats: [BatteryPackCostStat]
    let targetCurrency: String

    @State private var costPerDaySummary: String = "Loading…"
    private let currencyFormatter = CurrencyFormatter.shared

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
        .task {
            costPerDaySummary = await currencyFormatter.costPerDaySummaryConverted(
                from: costStats,
                targetCurrency: targetCurrency
            )
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

private struct AddEntryChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let activeAids: [HearingAid]
    let availablePacks: [BatteryPack]
    let packs: [BatteryPack]
    let defaultAidId: UUID?
    let onSaveBatteryLog: (HearingAid, Date, String?, UUID?) -> Void
    let onSavePack: (String, String?, Date, Int, Int, Decimal?, String?) throws -> Void
    private let issueLogService = IssueLogService()

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
                                try onSavePack(
                                    batteryType,
                                    brand,
                                    purchaseDate,
                                    batteriesPerPack,
                                    numberOfPacks,
                                    priceAmount,
                                    currencyCode
                                )
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

                    NavigationLink {
                        AddIssueLogSheet(
                            hearingAids: activeAids,
                            preselectedHearingAidId: selectedAidId ?? defaultAidId ?? activeAids.first?.id,
                            onSave: { timestamp, hearingAidId, issue, severity, note in
                                try issueLogService.saveFromSheet(
                                    aids: activeAids,
                                    hearingAidId: hearingAidId,
                                    timestamp: timestamp,
                                    issue: issue,
                                    severity: severity,
                                    note: note,
                                    context: context
                                )
                                dismiss()
                            },
                            onCancel: {
                                dismiss()
                            }
                        )
                    } label: {
                        AddItemActionRowLabel(
                            title: "Issue",
                            subtitle: issueSubtitle,
                            systemImage: "exclamationmark.bubble",
                            isDisabled: activeAids.isEmpty
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(activeAids.isEmpty)
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

    private var issueSubtitle: String {
        if activeAids.isEmpty {
            return "Add a hearing aid first"
        }
        return "What's the problem?"
    }
}

private struct AddItemActionRowLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isDisabled: Bool = false

    var body: some View {
        CardRowContainer {
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
        }
        .opacity(isDisabled ? 0.55 : 1)
    }
}
