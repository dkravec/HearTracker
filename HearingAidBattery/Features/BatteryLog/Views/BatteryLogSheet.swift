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
    @Binding var selectedPackId: UUID?
    let availablePacks: [BatteryPack]
    let onSave: (Date, String?) -> Void
    let onCancel: () -> Void

    /// When provided, shows a hearing-aid picker at the top of the form.
    var activeAids: [HearingAid] = []
    @Binding var selectedAidId: UUID?

    /// Whether the view is shown inside an existing NavigationStack (no wrapper needed).
    var wrapsInNavigationStack: Bool = true

    init(
        note: Binding<String>,
        timestamp: Binding<Date>,
        selectedPackId: Binding<UUID?>,
        availablePacks: [BatteryPack],
        onSave: @escaping (Date, String?) -> Void,
        onCancel: @escaping () -> Void,
        activeAids: [HearingAid] = [],
        selectedAidId: Binding<UUID?> = .constant(nil),
        wrapsInNavigationStack: Bool = true
    ) {
        self._note = note
        self._timestamp = timestamp
        self._selectedPackId = selectedPackId
        self.availablePacks = availablePacks
        self.onSave = onSave
        self.onCancel = onCancel
        self.activeAids = activeAids
        self._selectedAidId = selectedAidId
        self.wrapsInNavigationStack = wrapsInNavigationStack
    }

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack { formContent }
            } else {
                formContent
            }
        }
    }

    private var formContent: some View {
        Form {
            if activeAids.count > 1 {
                Section("Hearing Aid") {
                    Picker("Hearing Aid", selection: $selectedAidId) {
                        ForEach(activeAids) { aid in
                            Text(aid.name).tag(Optional(aid.id))
                        }
                    }
                }
            }

            Section("Logged At") {
                DatePicker(
                    "Timestamp",
                    selection: $timestamp,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section {
                Picker("Use Pack", selection: $selectedPackId) {
                    Text("Auto Match").tag(UUID?.none)
                    ForEach(availablePacks) { pack in
                        Text(packOptionLabel(for: pack)).tag(Optional(pack.id))
                    }
                }
            } header: {
                Text("Battery Pack")
            } footer: {
                Text("Auto Match uses the oldest non-empty pack matching this hearing aid's recent battery type.")
            }

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
                    onSave(timestamp, trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(.borderedProminent)
                .disabled(activeAids.count > 1 && selectedAidId == nil)
            }
        }
    }

    private func packOptionLabel(for pack: BatteryPack) -> String {
        let type = pack.batteryType.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = pack.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = brand.map { "\($0) " } ?? ""
        let date = pack.purchaseDate.formatted(date: .abbreviated, time: .omitted)
        return "\(prefix)\(type) • \(pack.quantityRemaining) left • \(date)"
    }
}
