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
            TextField("Name", text: $name)
            TextField("Model", text: $model)
            TextField("Battery Type (e.g. 312)", text: $batteryType)

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
        .navigationTitle("Add Hearing Aid")
        .errorAlert(title: "Unable to Create Hearing Aid", message: $errorMessage)
    }
}
