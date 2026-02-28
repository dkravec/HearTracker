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

    @StateObject private var viewModel = HearingAidDetailViewModel()
    @StateObject private var batteryStatusViewModel = BatteryStatusViewModel()
    private static let durationFormatter = BatteryDurationFormatter()
    private static let statsWindowSize: Int = 10

    init(aid: HearingAid) {
        self.aid = aid
        let hearingAidId = aid.id
        _logs = Query(
            filter: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId },
            sort: \BatteryLog.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let model = aid.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                    SectionHeaderView(title: model)
                }

                if viewModel.isEditing {
                    editSection
                }

                statsSection

                SectionHeaderView(title: "Battery Logs")
                    .padding(.top, viewModel.isEditing ? 4 : 0)

                if logs.isEmpty {
                    EmptyStateView(
                        title: "No Battery Logs",
                        systemImage: "battery.0",
                        message: "Tap the plus button to add the first battery log."
                    )
                }

                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                    NavigationLink(value: BatteryLogRoute(logId: log.id, hearingAidId: aid.id)) {
                        BatteryLogRow(log: log, rowModel: rowModel(for: index), showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isEditing)
                    .contextMenu {
                        if log.excludeFromStats == false {
                            Button("Exclude from averages") {
                                log.excludeFromStats = true
                                try? context.save()
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
        .onAppear { viewModel.syncFromAid(aid) }
        .task(id: logsRefreshSignature) {
            _ = batteryStatusViewModel.refresh(
                hearingAidId: aid.id,
                windowSize: Self.statsWindowSize,
                context: context
            )
        }
        .appBackground()
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

    private var editSection: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit Hearing Aid")
                    .font(.headline)

                TextField(
                    "Enter a new name",
                    text: $viewModel.editName,
                    prompt: Text(aid.name)
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

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
        viewModel.deleteHearingAid(aid, context: context)
        dismiss()
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

}
