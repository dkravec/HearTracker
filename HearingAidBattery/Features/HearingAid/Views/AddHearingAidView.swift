//
//  AddHearingAidView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData

struct AddHearingAidView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var model: String = ""
    @State private var batteryType: String = ""
    @State private var errorMessage: String?

    private let hearingAidService = HearingAidService()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Hearing Aid") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter hearing aid name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Model (Optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter model", text: $model)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Battery Type (Optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 312", text: $batteryType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Button("Create") {
                do {
                    try hearingAidService.createHearingAid(
                        name: name,
                        model: model,
                        batteryType: batteryType,
                        context: context
                    )
                    dismiss()
                } catch {
                    errorMessage = "Could not create hearing aid."
                }
            }
            .disabled(trimmedName.isEmpty)
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Add Hearing Aid")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(title: "Unable to Create Hearing Aid", message: $errorMessage)
    }
}
