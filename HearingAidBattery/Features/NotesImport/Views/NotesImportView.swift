import SwiftUI
import SwiftData

struct NotesImportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]

    @State private var rawInput: String = ""
    @State private var selectedHearingAidId: UUID?
    @State private var previewItems: [NotesImportPreviewItem] = []
    @State private var unknownLines: [String] = []
    @State private var warnings: [String] = []
    @State private var commitMessage: String?

    private let parser = NotesImportParserService()
    private let commitService = NotesImportCommitService()

    private var activeAids: [HearingAid] {
        hearingAids.filter { !$0.retired }
    }

    private var unresolvedItems: [NotesImportPreviewItem] {
        previewItems.filter { $0.resolvedTimestamp == nil }
    }

    private var groupedPreviewItems: [Date: [NotesImportPreviewItem]] {
        var grouped: [Date: [NotesImportPreviewItem]] = [:]
        for item in previewItems {
            guard let date = item.resolvedTimestamp else { continue }
            let day = Calendar.current.startOfDay(for: date)
            grouped[day, default: []].append(item)
        }
        return grouped
    }

    var body: some View {
        List {
            Section("Import Target") {
                if activeAids.isEmpty {
                    Text("Add a hearing aid before importing notes.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Hearing Aid", selection: $selectedHearingAidId) {
                        Text("Select").tag(Optional<UUID>.none)
                        ForEach(activeAids) { aid in
                            Text(aid.name).tag(Optional(aid.id))
                        }
                    }
                }
            }

            Section("Paste Notes") {
                TextEditor(text: $rawInput)
                    .frame(minHeight: 140)
                Button("Parse") {
                    parseNotes()
                }
                .disabled(rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if previewItems.isEmpty == false {
                Section("Preview") {
                    if unresolvedItems.isEmpty == false {
                        Text("Needs Date/Time")
                            .font(.headline)
                        ForEach(unresolvedItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.originalLine)
                                    .font(.subheadline)
                                DatePicker(
                                    "Resolve Date/Time",
                                    selection: bindingDate(for: item.id),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                            }
                        }
                    }

                    ForEach(groupedPreviewItems.keys.sorted(by: >), id: \.self) { day in
                        Text(day.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline)
                        ForEach(groupedPreviewItems[day] ?? []) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.kind == .battery ? "Battery" : "Issue")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.text.isEmpty ? item.originalLine : item.text)
                                    .font(.subheadline)
                                if let date = item.resolvedTimestamp {
                                    Text(date.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if unknownLines.isEmpty == false {
                Section("Unknown Lines") {
                    ForEach(unknownLines, id: \.self) { line in
                        Text(line)
                    }
                }
            }

            if warnings.isEmpty == false {
                Section("Warnings") {
                    ForEach(warnings, id: \.self) { warning in
                        Text(warning)
                    }
                }
            }

            Section {
                Button("Commit Import") {
                    commitImport()
                }
                .disabled(previewItems.isEmpty || unresolvedItems.isEmpty || selectedHearingAid == nil)
            }
        }
        .navigationTitle("Notes Import")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Import Result", isPresented: Binding(
            get: { commitMessage != nil },
            set: { newValue in
                if !newValue { commitMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(commitMessage ?? "")
        }
    }

    private var selectedHearingAid: HearingAid? {
        guard let selectedHearingAidId else { return nil }
        return activeAids.first(where: { $0.id == selectedHearingAidId })
    }

    private func parseNotes() {
        let result = parser.parse(rawInput)
        previewItems = result.allItems
            .sorted {
                let lhs = $0.timestamp ?? .distantPast
                let rhs = $1.timestamp ?? .distantPast
                return lhs > rhs
            }
            .map { item in
                NotesImportPreviewItem(parsed: item)
            }
        unknownLines = result.unknownLines
        warnings = result.warnings
    }

    private func commitImport() {
        guard let selectedHearingAid else { return }
        let result = try? commitService.commit(items: previewItems, hearingAid: selectedHearingAid, context: context)
        if let result {
            commitMessage = "Created \(result.createdBatteryLogs) battery logs, \(result.createdIssues) issues. Skipped \(result.skippedDuplicates) duplicates and \(result.unresolvedSkipped) unresolved lines."
        } else {
            commitMessage = "Import failed."
        }
    }

    private func bindingDate(for itemId: UUID) -> Binding<Date> {
        Binding(
            get: {
                previewItems.first(where: { $0.id == itemId })?.resolvedTimestamp ?? Date()
            },
            set: { newValue in
                if let index = previewItems.firstIndex(where: { $0.id == itemId }) {
                    previewItems[index].resolvedTimestamp = newValue
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        NotesImportView()
    }
}
