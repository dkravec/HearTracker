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

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Model", text: $model)
            Button("Create") {
                let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
                let aid = HearingAid(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: trimmedModel.isEmpty ? nil : trimmedModel
                )
                context.insert(aid)
                try? context.save()
                dismiss()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Add Hearing Aid")
    }
}
