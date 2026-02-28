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
    @StateObject private var logListViewModel = BatteryLogListViewModel()
    @StateObject private var statusViewModel = BatteryStatusViewModel()

    init(aid: HearingAid) {
        self.aid = aid
        let hearingAidId = aid.id
        _logs = Query(
            filter: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId },
            sort: \BatteryLog.timestamp,
            order: .reverse
        )
    }

    private var refreshSignature: String {
        let logsSignature = logs
            .map { "\($0.id.uuidString)-\($0.timestamp.timeIntervalSince1970)-\($0.note ?? "")" }
            .joined(separator: "|")

        return "\(aid.id.uuidString)-\(aid.name)-\(aid.model ?? "")-\(aid.retired)-\(logsSignature)"
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

                SectionHeaderView(title: "Battery Logs")
                    .padding(.top, viewModel.isEditing ? 4 : 0)

                if logs.isEmpty {
                    EmptyStateView(
                        title: "No Battery Logs",
                        systemImage: "battery.0",
                        message: "Tap the plus button to add the first battery log."
                    )
                }

                ForEach(Array(zip(logs, logListViewModel.rows)), id: \.0.id) { log, rowModel in
                    BatteryLogRow(log: log, rowModel: rowModel)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteLog(log)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(aid.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.beginLog()
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(viewModel.isEditing ? "Done" : "Edit") {
                    if viewModel.isEditing {
                        viewModel.endEditing(resetWith: aid, reset: true)
                    } else {
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
                onSave: { note in
                    viewModel.saveLog(for: aid, note: note, context: context)
                    refreshDerivedState()
                },
                onSaveWithoutNote: {
                    viewModel.saveLogWithoutNote(for: aid, context: context)
                    refreshDerivedState()
                },
                onCancel: {
                    viewModel.endLog()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .task(id: refreshSignature) {
            refreshDerivedState()
            viewModel.syncFromAid(aid)
        }
        .appBackground()
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

                HStack {
                    Button("Cancel") {
                        viewModel.endEditing(resetWith: aid, reset: true)
                    }

                    Spacer()

                    Button("Save Changes") {
                        viewModel.saveEdits(for: aid, context: context)
                        refreshDerivedState()
                    }
                    .buttonStyle(.borderedProminent)
                }

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

    private func refreshDerivedState() {
        let snapshot = statusViewModel.refresh(
            hearingAidId: aid.id,
            windowSize: 0,
            context: context
        )
        logListViewModel.refresh(sortedLogs: logs, currentLogId: snapshot.currentLogId)
    }

    private func deleteHearingAid() {
        viewModel.deleteHearingAid(aid, context: context)
        dismiss()
    }

    private func deleteLog(_ log: BatteryLog) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        viewModel.deleteLogs(at: IndexSet(integer: index), logs: logs, context: context)
        refreshDerivedState()
    }
}
