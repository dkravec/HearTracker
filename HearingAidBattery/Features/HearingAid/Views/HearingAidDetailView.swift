//
//  HearingAidDetailView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData

struct HearingAidDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let aid: HearingAid
    @Query private var logs: [BatteryLog]
    @Query private var packs: [BatteryPack]

    @StateObject private var viewModel = HearingAidDetailViewModel()
    @StateObject private var batteryStatusViewModel = BatteryStatusViewModel()
    @State private var logErrorMessage: String?
    @State private var selectedLogSelection: LogSelection?

    private let batteryLogService: BatteryLogProviding = BatteryLogService()
    private static let durationFormatter = BatteryDurationFormatter()
    private static let statsWindowSize: Int = 10

    init(aid: HearingAid) {
        self.aid = aid
        let hearingAidId = aid.id
        let spaceId = aid.spaceId
        _logs = Query(
            filter: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId && $0.spaceId == spaceId },
            sort: \BatteryLog.timestamp,
            order: .reverse
        )
        _packs = Query(
            filter: #Predicate<BatteryPack> { $0.spaceId == spaceId },
            sort: \BatteryPack.purchaseDate,
            order: .forward
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let model = aid.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                    SectionHeaderView(title: model)
                }
                if let batteryType = aid.batteryType?.trimmingCharacters(in: .whitespacesAndNewlines), !batteryType.isEmpty {
                    CardRowContainer {
                        Text("Battery Type: \(batteryType)")
                            .font(.subheadline)
                    }
                }

                if viewModel.isEditing {
                    editSection
                }

                if viewModel.showsInventoryWarning {
                    inventoryWarningCard
                }

                statsSection

                NavigationLink {
                    IssueLogView(hearingAid: aid)
                } label: {
                    CardRowContainer {
                        HStack {
                            Label("Issue History", systemImage: "exclamationmark.bubble")
                                .font(.headline)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                SectionHeaderView(title: "Battery Logs")
                    .padding(.top, viewModel.isEditing ? 4 : 0)

                if logs.isEmpty {
                    EmptyStateView(
                        title: "No Battery Logs",
                        systemImage: FeatureSymbols.batteryLog,
                        message: "Tap the plus button to add the first battery log."
                    )
                }

                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                    Button {
                        selectedLogSelection = LogSelection(id: log.id)
                    } label: {
                        BatteryLogRow(log: log, rowModel: rowModel(for: index), showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isEditing)
                    .contextMenu {
                        if log.excludeFromStats == false {
                            Button("Exclude from averages") {
                                viewModel.excludeFromAverages(log, hearingAidId: aid.id, context: context)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(aid.name)
        .toolbar {
            if viewModel.isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.endEditing(resetWith: aid, reset: true)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveEdits(for: aid, context: context)
                    }
                    .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.beginLog()
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        viewModel.beginEditing(with: aid)
                    }
                }
            }
        }
        .alert("Delete Hearing Aid?", isPresented: $viewModel.showsDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteHearingAid()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the hearing aid and all its battery logs.")
        }
        .sheet(isPresented: $viewModel.showsLogSheet) {
            BatteryLogSheet(
                note: $viewModel.logNote,
                timestamp: $viewModel.logTimestamp,
                selectedPackId: $viewModel.selectedPackId,
                availablePacks: availablePacks,
                onSave: { timestamp, note in
                    viewModel.saveLog(for: aid, timestamp: timestamp, note: note, context: context)
                },
                onCancel: {
                    viewModel.endLog()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .sheet(item: $selectedLogSelection) { selection in
            NavigationStack {
                if let index = logs.firstIndex(where: { $0.id == selection.id }) {
                    let log = logs[index]
                    BatteryLogDetailView(
                        log: log,
                        rowModel: rowModel(for: index),
                        onSave: { timestamp, note, excludeFromStats, excludePreviousGapFromStats in
                            do {
                                try batteryLogService.updateLog(
                                    log,
                                    timestamp: timestamp,
                                    note: note,
                                    excludeFromStats: excludeFromStats,
                                    excludePreviousGapFromStats: excludePreviousGapFromStats,
                                    context: context
                                )
                            } catch {
                                logErrorMessage = "Could not save battery log changes."
                            }
                        },
                        onDelete: {
                            do {
                                try batteryLogService.deleteLog(log, context: context)
                            } catch {
                                logErrorMessage = "Could not delete battery log."
                            }
                        }
                    )
                } else {
                    ContentUnavailableView("Log Not Found", systemImage: "questionmark.circle")
                }
            }
            .appBackground()
        }
        .onAppear { viewModel.syncFromAid(aid) }
        .task(id: logsRefreshSignature) {
            _ = batteryStatusViewModel.refresh(
                hearingAidId: aid.id,
                windowSize: Self.statsWindowSize,
                context: context
            )
        }
        .appBackground()
        .errorAlert(title: "Unable to Save", message: $viewModel.errorMessage)
        .errorAlert(title: "Unable to Save Battery Log", message: $logErrorMessage)
    }

    private var statsSection: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("Battery Stats")
                    .font(.headline)

                statsRow(
                    title: "Current battery age",
                    value: batteryStatusViewModel.currentBatteryAgeText ?? "Not enough data"
                )
                statsRow(
                    title: "Average duration (last \(Self.statsWindowSize))",
                    value: batteryStatusViewModel.averageDurationText ?? "Not enough data"
                )
                statsRow(
                    title: "Predicted death",
                    value: batteryStatusViewModel.predictedDeathText ?? "Not enough data"
                )
            }
        }
    }

    private var inventoryWarningCard: some View {
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

    private var editSection: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit Hearing Aid")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Enter hearing aid name",
                        text: $viewModel.editName,
                        prompt: Text(aid.name)
                    )
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Model (optional)",
                        text: $viewModel.editModel,
                        prompt: Text(aid.model?.isEmpty == false ? (aid.model ?? "") : "Model (Optional)")
                    )
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Battery Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Battery Type (optional)",
                        text: $viewModel.editBatteryType,
                        prompt: Text(aid.batteryType?.isEmpty == false ? (aid.batteryType ?? "") : "Battery Type (Optional)")
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Toggle("Mark as retired", isOn: $viewModel.editRetired)

                Divider()

                Button(role: .destructive) {
                    viewModel.showsDeleteAlert = true
                } label: {
                    Label("Delete Hearing Aid", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func deleteHearingAid() {
        if viewModel.deleteHearingAid(aid, context: context) {
            dismiss()
        }
    }

    private func rowModel(for index: Int) -> BatteryLogRowModel {
        let log = logs[index]
        let duration: TimeInterval? = {
            guard index > 0 else { return nil }
            let newerLog = logs[index - 1]
            let interval = newerLog.timestamp.timeIntervalSince(log.timestamp)
            return interval > 0 ? interval : nil
        }()

        return BatteryLogRowModel(
            id: log.id,
            isCurrent: index == 0,
            rawDuration: duration,
            durationText: Self.durationFormatter.optionalDaysText(from: duration)
        )
    }

    private func statsRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
        }
    }

    private var logsRefreshSignature: String {
        logs
            .map {
                "\($0.id.uuidString)-\($0.timestamp.timeIntervalSince1970)-\($0.excludeFromStats)-\($0.excludePreviousGapFromStats)"
            }
            .joined(separator: "|")
    }

    private var availablePacks: [BatteryPack] {
        packs.filter { $0.quantityRemaining > 0 && $0.isDone == false }
    }

}

private struct LogSelection: Identifiable {
    let id: UUID
}
