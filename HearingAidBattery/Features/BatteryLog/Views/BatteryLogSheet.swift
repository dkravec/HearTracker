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
    @Binding var selectedLotId: UUID?
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
        selectedLotId: Binding<UUID?>,
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
        self._selectedLotId = selectedLotId
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

            if availableLotsForSelectedPack.isEmpty == false {
                Section {
                    Picker("Use Lot", selection: $selectedLotId) {
                        Text("Auto Match (Best Option)").tag(UUID?.none)

                        ForEach(openLotsForSelectedPack, id: \.id) { lot in
                            Text(lotOptionLabel(for: lot, opened: true)).tag(Optional(lot.id))
                        }

                        ForEach(unopenedLotsForSelectedPack, id: \.id) { lot in
                            Text(lotOptionLabel(for: lot, opened: false)).tag(Optional(lot.id))
                        }
                    }
                } header: {
                    Text("Pack Lot")
                } footer: {
                    Text("Auto Match (Best Option) chooses the best lot from this pack, preferring opened lots first.")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note (Optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Add context for this battery log", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            } header: {
                Text("Battery Log")
            } footer: {
                Text("Leave blank to log without a note.")
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("New Battery Log")
        .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: selectedPackId) {
            sanitizeSelectedLot()
        }
    }

    private func packOptionLabel(for pack: BatteryPack) -> String {
        let type = pack.batteryType.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = pack.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = brand.map { "\($0) " } ?? ""
        let date = pack.purchaseDate.formatted(date: .abbreviated, time: .omitted)
        return "\(prefix)\(type) • \(pack.quantityRemaining) left • \(date)"
    }

    private var selectedPack: BatteryPack? {
        guard let selectedPackId else { return nil }
        return availablePacks.first(where: { $0.id == selectedPackId })
    }

    private var availableLotsForSelectedPack: [BatteryPackLot] {
        guard let selectedPack else { return [] }
        return (selectedPack.lots ?? [])
            .filter { $0.isMarkedLost == false && $0.quantityRemaining > 0 }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    private var openLotsForSelectedPack: [BatteryPackLot] {
        availableLotsForSelectedPack
            .filter { $0.openedAt != nil }
            .sorted {
                guard let left = $0.openedAt, let right = $1.openedAt else { return false }
                return left < right
            }
    }

    private var unopenedLotsForSelectedPack: [BatteryPackLot] {
        availableLotsForSelectedPack
            .filter { $0.openedAt == nil }
            .sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    private func lotOptionLabel(for lot: BatteryPackLot, opened: Bool) -> String {
        if opened, let openedAt = lot.openedAt {
            return "Pack \(lot.sortIndex + 1) • opened \(openedAt.formatted(date: .abbreviated, time: .shortened)) • \(lot.quantityRemaining) left"
        }
        return "Pack \(lot.sortIndex + 1) • unopened • \(lot.quantityRemaining) left"
    }

    private func sanitizeSelectedLot() {
        guard let selectedLotId else { return }
        let lotStillAvailable = availableLotsForSelectedPack.contains(where: { $0.id == selectedLotId })
        if lotStillAvailable == false {
            self.selectedLotId = nil
        }
    }
}
