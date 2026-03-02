//
//  BatteryLogDetailView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import SwiftUI
import SwiftData

/// Self-contained wrapper that resolves a ``BatteryLogRoute`` into the full
/// ``BatteryLogDetailView``.  Designed to be used at the `NavigationStack`
/// level so nested-destination bugs are avoided.
struct BatteryLogDetailContainer: View {
    @Environment(\.modelContext) private var context

    let route: BatteryLogRoute
    @Query private var logs: [BatteryLog]
    @State private var errorMessage: String?

    private static let durationFormatter = BatteryDurationFormatter()
    private let batteryLogService: BatteryLogProviding = BatteryLogService()

    init(route: BatteryLogRoute) {
        self.route = route
        let hearingAidId = route.hearingAidId
        _logs = Query(
            filter: #Predicate<BatteryLog> { $0.hearingAid?.id == hearingAidId },
            sort: \BatteryLog.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        Group {
            if let (log, rowModel) = resolvedLogAndRow() {
                BatteryLogDetailView(
                    log: log,
                    rowModel: rowModel,
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
                            errorMessage = "Could not save battery log changes."
                        }
                    },
                    onDelete: {
                        do {
                            try batteryLogService.deleteLog(log, context: context)
                        } catch {
                            errorMessage = "Could not delete battery log."
                        }
                    }
                )
            } else {
                ContentUnavailableView("Log Not Found", systemImage: "questionmark.circle")
            }
        }
        .errorAlert(title: "Unable to Save Battery Log", message: $errorMessage)
    }

    private func resolvedLogAndRow() -> (BatteryLog, BatteryLogRowModel)? {
        for (index, log) in logs.enumerated() where log.id == route.logId {
            let duration: TimeInterval? = {
                guard index > 0 else { return nil }
                let newerLog = logs[index - 1]
                let interval = newerLog.timestamp.timeIntervalSince(log.timestamp)
                return interval > 0 ? interval : nil
            }()

            let rowModel = BatteryLogRowModel(
                id: log.id,
                isCurrent: index == 0,
                rawDuration: duration,
                durationText: Self.durationFormatter.optionalDaysText(from: duration)
            )
            return (log, rowModel)
        }
        return nil
    }
}

struct BatteryLogDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let log: BatteryLog
    let rowModel: BatteryLogRowModel
    let onSave: (Date, String?, Bool, Bool) -> Void
    let onDelete: () -> Void

    @State private var isEditing: Bool = false
    @State private var showsDeleteAlert: Bool = false
    @State private var draftTimestamp: Date
    @State private var draftNote: String
    @State private var draftExcludeFromStats: Bool
    @State private var draftExcludePreviousGapFromStats: Bool

    init(
        log: BatteryLog,
        rowModel: BatteryLogRowModel,
        onSave: @escaping (Date, String?, Bool, Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.log = log
        self.rowModel = rowModel
        self.onSave = onSave
        self.onDelete = onDelete
        _draftTimestamp = State(initialValue: log.timestamp)
        _draftNote = State(initialValue: log.note ?? "")
        _draftExcludeFromStats = State(initialValue: log.excludeFromStats)
        _draftExcludePreviousGapFromStats = State(initialValue: log.excludePreviousGapFromStats)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if isEditing {
                    editSection
                } else {
                    readOnlySection
                }

                CardRowContainer {
                    Button(role: .destructive) {
                        showsDeleteAlert = true
                    } label: {
                        Label("Delete Log", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Battery Log")
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            draftTimestamp,
                            trimmed.isEmpty ? nil : trimmed,
                            draftExcludeFromStats,
                            draftExcludePreviousGapFromStats
                        )
                        isEditing = false
                    }
                    .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        beginEditing()
                    }
                }
            }
        }
        .alert("Delete Battery Log?", isPresented: $showsDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .appBackground()
    }

    // MARK: - Read-only

    private var readOnlySection: some View {
        Group {
            CardRowContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text(rowModel.isCurrent ? "Current Battery" : "Previous Battery")
                        .font(.headline)

                    Text(log.timestamp.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)

                    if let durationText = rowModel.durationText {
                        Text("Lasted: \(durationText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            CardRowContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.headline)

                    if let note = log.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                    } else {
                        Text("No note for this log.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Inline edit

    private var editSection: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit Battery Log")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Timestamp")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "Logged At",
                        selection: $draftTimestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Add a note (optional)", text: $draftNote, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Exclude this battery from averages", isOn: $draftExcludeFromStats)
                Toggle("Forgot previous log (exclude previous gap)", isOn: $draftExcludePreviousGapFromStats)
            }
        }
    }

    private func beginEditing() {
        draftTimestamp = log.timestamp
        draftNote = log.note ?? ""
        draftExcludeFromStats = log.excludeFromStats
        draftExcludePreviousGapFromStats = log.excludePreviousGapFromStats
        isEditing = true
    }

    private func cancelEditing() {
        draftTimestamp = log.timestamp
        draftNote = log.note ?? ""
        draftExcludeFromStats = log.excludeFromStats
        draftExcludePreviousGapFromStats = log.excludePreviousGapFromStats
        isEditing = false
    }
}
