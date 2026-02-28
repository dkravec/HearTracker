//
//  SettingView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]

    @State private var showsDeleteAllDataAlert: Bool = false
    @State private var showsDeleteLogsSheet: Bool = false
    @State private var showsDeleteLogsAlert: Bool = false
    @State private var pendingDeleteLogsAidId: UUID?
    @State private var resultMessage: String?

    private let settingService = SettingService()

    var body: some View {
        List {
            Section("General") {
                Label("Settings", systemImage: "gearshape")
            }

            Section("Data") {
                NavigationLink {
                    NotesImportView()
                } label: {
                    Label("Notes Import", systemImage: "square.and.arrow.down")
                }
            }

            Section("Danger Zone") {
                Button("Delete Battery Logs", role: .destructive) {
                    showsDeleteLogsSheet = true
                }
                Button("Delete All Data", role: .destructive) {
                    showsDeleteAllDataAlert = true
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete All Data?", isPresented: $showsDeleteAllDataAlert) {
            Button("Delete", role: .destructive) {
                do {
                    let count = try settingService.deleteAllData(context: context)
                    resultMessage = "Deleted \(count) records."
                } catch {
                    resultMessage = "Delete failed."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove hearing aids, battery logs, packs, and issues.")
        }
        .sheet(isPresented: $showsDeleteLogsSheet) {
            NavigationStack {
                List {
                    Section("Choose Scope") {
                        Button("All Hearing Aids") {
                            pendingDeleteLogsAidId = nil
                            showsDeleteLogsSheet = false
                            showsDeleteLogsAlert = true
                        }
                        .foregroundStyle(.red)

                        ForEach(activeAids) { aid in
                            Button(aid.name) {
                                pendingDeleteLogsAidId = aid.id
                                showsDeleteLogsSheet = false
                                showsDeleteLogsAlert = true
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Delete Battery Logs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showsDeleteLogsSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .background(AppBackgroundView())
        }
        .alert("Delete Battery Logs?", isPresented: $showsDeleteLogsAlert) {
            Button("Delete", role: .destructive) {
                do {
                    let count = try settingService.deleteBatteryLogs(for: pendingDeleteLogsAidId, context: context)
                    resultMessage = "Deleted \(count) battery logs."
                } catch {
                    resultMessage = "Delete failed."
                }
                pendingDeleteLogsAidId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteLogsAidId = nil
            }
        } message: {
            Text(deleteLogsAlertMessage)
        }
        .alert("Done", isPresented: Binding(
            get: { resultMessage != nil },
            set: { newValue in
                if !newValue { resultMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private var activeAids: [HearingAid] {
        hearingAids.filter { !$0.retired }
    }

    private var deleteLogsAlertMessage: String {
        if let id = pendingDeleteLogsAidId, let aid = hearingAids.first(where: { $0.id == id }) {
            return "This only deletes battery logs for \(aid.name)."
        }
        return "This only deletes battery logs for all hearing aids."
    }
}

#Preview {
    NavigationStack {
        SettingView()
    }
}
