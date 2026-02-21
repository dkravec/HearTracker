//
//  LogBatterySheet.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI

struct LogBatterySheet: View {
    @Binding var note: String
    let onSave: (String?) -> Void
    let onSaveWithoutNote: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Battery Log")
                } footer: {
                    Text("Leave blank to log without a note.")
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
                        onSave(trimmed.isEmpty ? nil : trimmed)
                    }
                    .buttonStyle(.borderedProminent)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Save Without Note") {
                        onSaveWithoutNote()
                    }
                }
            }
        }
    }
}
