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
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var aids: [HearingAid]

    @State private var showsRetired: Bool = false
    @State private var logTargetAid: HearingAid?
    @State private var logNote: String = ""

    private let service = BatteryLogService()

    private var activeAids: [HearingAid] {
        aids.filter { !$0.retired }
    }

    private var retiredAids: [HearingAid] {
        aids.filter { $0.retired }
    }

    var body: some View {
        NavigationStack {
            List {
                if activeAids.isEmpty {
                    ContentUnavailableView(
                        "No Hearing Aids",
                        systemImage: "ear",
                        description: Text("Add a hearing aid to start tracking battery changes.")
                    )
                }

                ForEach(activeAids) { aid in
                    hearingAidRow(for: aid)
                }

                if showsRetired, !retiredAids.isEmpty {
                    Section("Retired") {
                        ForEach(retiredAids) { aid in
                            hearingAidRow(for: aid)
                        }
                    }
                }
            }
            .navigationTitle("Hearing Aids")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Add") { AddHearingAidView() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !retiredAids.isEmpty {
                        Button(showsRetired ? "Hide Retired" : "Show Retired") {
                            showsRetired.toggle()
                        }
                    }
                }
            }
        }
        .sheet(item: $logTargetAid) { aid in
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
    }

    @ViewBuilder
    private func hearingAidRow(for aid: HearingAid) -> some View {
        NavigationLink {
            HearingAidDetailView(aid: aid)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(aid.name)
                        .font(.headline)
                    if let model = aid.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                        Text(model)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(aid.batteryChangeCount) changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Log") {
                    beginLog(for: aid)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)
        }
    }

    private func beginLog(for aid: HearingAid) {
        logNote = ""
        logTargetAid = aid
    }

    private func endLog() {
        logNote = ""
        logTargetAid = nil
    }
}
