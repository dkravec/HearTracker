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
    private static let durationFormatter = BatteryDurationFormatter()

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
                onSave: { note in
                    viewModel.saveLog(for: aid, note: note, context: context)
                },
                onSaveWithoutNote: {
                    viewModel.saveLogWithoutNote(for: aid, context: context)
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

}
