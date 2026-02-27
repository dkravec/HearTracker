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
    @Bindable var aid: HearingAid
    
    @State private var isEditing: Bool = false
    @State private var editName: String = ""
    @State private var editModel: String = ""
    @State private var editRetired: Bool = false
    @State private var showsDeleteAlert: Bool = false
    @State private var showsLogSheet: Bool = false
    @State private var logNote: String = ""

    private let service = BatteryLogService()

    var sortedLogs: [BatteryLog] {
        (aid.logs ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            if isEditing {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Edit Hearing Aid")
                            .font(.headline)
                        TextField(
                            "Enter a new name",
                            text: $editName,
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
                                text: $editModel,
                                prompt: Text(aid.model?.isEmpty == false ? (aid.model ?? "") : "Model (Optional)")
                            )
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        }
                        Toggle("Mark as retired", isOn: $editRetired)
                        HStack {
                            Button("Cancel") {
                                endEditing(reset: true)
                            }
                            Spacer()
                            Button("Save Changes") {
                                saveEdits()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Divider()
                        Button(role: .destructive) {
                            showsDeleteAlert = true
                        } label: {
                            Label("Delete Hearing Aid", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
                .contentShape(Rectangle())
                .onTapGesture { }
            }

            ForEach(sortedLogs) { log in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(log.timestamp, style: .date)
                        Text(log.timestamp, style: .time)
                        Spacer()
                        if log.isCurrent {
                            Text("Current").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let note = log.note, !note.isEmpty {
                        Text(note).font(.subheadline)
                    }
                    if let d = durationString(for: log, in: aid.logs ?? []) {
                        Text("Lasted: \(d)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteLogs)
        }
        .navigationTitle(aid.name)
        .safeAreaInset(edge: .top) {
            if let model = aid.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                Text(model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    beginLog()
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        endEditing(reset: true)
                    } else {
                        beginEditing()
                    }
                }
            }
        }
        .alert("Delete Hearing Aid?", isPresented: $showsDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteHearingAid()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the hearing aid and all its battery logs.")
        }
        .sheet(isPresented: $showsLogSheet) {
            LogBatterySheet(
                note: $logNote,
                onSave: { note in
                    try? service.quickLog(for: aid, note: note, context: context)
                    endLog()
                },
                onSaveWithoutNote: {
                    try? service.quickLog(for: aid, context: context)
                    endLog()
                },
                onCancel: {
                    endLog()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            endEditing(reset: true)
        }
    }
}

private extension HearingAidDetailView {
    func beginEditing() {
        editName = ""
        editModel = ""
        editRetired = aid.retired
        isEditing = true
    }

    func endEditing(reset: Bool) {
        if reset {
            editName = aid.name
            editModel = aid.model ?? ""
            editRetired = aid.retired
        }
        isEditing = false
    }

    func saveEdits() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = editModel.trimmingCharacters(in: .whitespacesAndNewlines)
        aid.name = trimmedName.isEmpty ? aid.name : trimmedName
        aid.model = trimmedModel.isEmpty ? nil : trimmedModel
        aid.retired = editRetired
        try? context.save()
        endEditing(reset: true)
    }

    func deleteHearingAid() {
        context.delete(aid)
        try? context.save()
        dismiss()
    }

    func deleteLogs(at offsets: IndexSet) {
        let logs = sortedLogs
        for index in offsets {
            context.delete(logs[index])
        }
        try? context.save()
    }

    func beginLog() {
        logNote = ""
        showsLogSheet = true
    }

    func endLog() {
        logNote = ""
        showsLogSheet = false
    }
}

