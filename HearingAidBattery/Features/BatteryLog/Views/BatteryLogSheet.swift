//
//  BatteryLogSheet.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI

struct BatteryLogSheet: View {
    @Binding var note: String
    @Binding var timestamp: Date
    let onSave: (Date, String?) -> Void
    let onSaveWithoutNote: (Date) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Logged At") {
                    DatePicker(
                        "Timestamp",
                        selection: $timestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Battery Log")
                } footer: {
                    Text("Leave blank to log without a note.")
                }

                Section {
                    Button("Save Log") {
                        onSaveWithoutNote(timestamp)
                    }
                }
            }
            .navigationTitle("New Battery Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(timestamp, trimmed.isEmpty ? nil : trimmed)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
