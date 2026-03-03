import SwiftUI
import SwiftData

struct NotesImportView: View {
    private enum PreviewTab: String, CaseIterable {
        case imports = "Imports"
        case review = "To Review"
    }

    private enum FocusField: Hashable {
        case rawInput
        case note(UUID)
        case rejectedNote(UUID)
    }

    private struct RejectedLineDraft: Identifiable {
        let id: UUID = UUID()
        let line: String
        var kind: NotesImportItemKind = .battery
        var timestamp: Date = Date()
        var note: String = ""
    }

    @Environment(\.modelContext) private var context

    @State private var activeAids: [HearingAid] = []
    @State private var hasLoaded: Bool = false
    @State private var rawInput: String = ""
    @State private var selectedHearingAidId: UUID?
    @State private var previewItems: [NotesImportPreviewItem] = []
    @State private var rejectedDrafts: [RejectedLineDraft] = []
    @State private var warnings: [String] = []
    @State private var commitMessage: String?
    @State private var selectedTab: PreviewTab = .imports

    @FocusState private var focusedField: FocusField?

    private let parser = NotesImportParserService()
    private let commitService = NotesImportCommitService()

    private var reviewItems: [NotesImportPreviewItem] {
        previewItems.filter { needsReview($0) }
    }

    private var unresolvedItems: [NotesImportPreviewItem] {
        reviewItems
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Import Target")
                CardRowContainer {
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

                SectionHeaderView(title: "Paste Notes")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $rawInput)
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($focusedField, equals: .rawInput)

                        Button("Parse") {
                            focusedField = nil
                            parseNotes()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if previewItems.isEmpty == false {
                    SectionHeaderView(title: "Preview")
                    CardRowContainer {
                        Picker("Preview Tab", selection: $selectedTab) {
                            ForEach(PreviewTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if selectedTab == .imports {
                        ForEach(previewItems) { item in
                            importItemCard(item)
                        }
                    } else {
                        if reviewItems.isEmpty && rejectedDrafts.isEmpty && warnings.isEmpty {
                            EmptyStateView(
                                title: "No Review Needed",
                                systemImage: "checkmark.circle",
                                message: "All parsed items are ready to commit."
                            )
                        } else {
                            if reviewItems.isEmpty == false {
                                SectionHeaderView(title: "Items to Review")
                                ForEach(reviewItems) { item in
                                    importItemCard(item)
                                }
                            }

                            if rejectedDrafts.isEmpty == false {
                                SectionHeaderView(title: "Rejected Lines")
                                ForEach(rejectedDrafts) { draft in
                                    CardRowContainer {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(draft.line)
                                                .font(.subheadline)

                                            Picker("Target", selection: bindingRejectedKind(for: draft.id)) {
                                                Text("Battery").tag(NotesImportItemKind.battery)
                                                Text("Issue").tag(NotesImportItemKind.issue)
                                            }
                                            .pickerStyle(.segmented)

                                            DatePicker(
                                                "Date & Time",
                                                selection: bindingRejectedDate(for: draft.id),
                                                displayedComponents: [.date, .hourAndMinute]
                                            )

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Notes")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                TextField(
                                                    "Type notes",
                                                    text: bindingRejectedNote(for: draft.id),
                                                    axis: .vertical
                                                )
                                                .lineLimit(2...4)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(Color(.secondarySystemBackground))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                                )
                                                .focused($focusedField, equals: .rejectedNote(draft.id))
                                            }

                                            Button("Add to Imports") {
                                                addRejectedDraftToImports(draft.id)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }

                            if warnings.isEmpty == false {
                                SectionHeaderView(title: "Warnings")
                                ForEach(warnings, id: \.self) { warning in
                                    CardRowContainer {
                                        Text(warning)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                CardRowContainer {
                    Button("Commit Import") {
                        focusedField = nil
                        commitImport()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(previewItems.isEmpty || unresolvedItems.isEmpty == false || selectedHearingAid == nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Notes Import")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .onAppear {
            loadData()
        }
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

    private func loadData() {
        guard hasLoaded == false else { return }
        let activeSpaceId = SpaceService.activeSpaceIdForQueries
        let descriptor = FetchDescriptor<HearingAid>(
            predicate: #Predicate<HearingAid> { $0.spaceId == activeSpaceId && $0.retired == false },
            sortBy: [SortDescriptor(\HearingAid.createdAt, order: .reverse)]
        )
        activeAids = (try? context.fetch(descriptor)) ?? []
        hasLoaded = true
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
        rejectedDrafts = result.unknownLines.map { RejectedLineDraft(line: $0) }
        warnings = result.warnings
        selectedTab = (reviewItems.isEmpty && rejectedDrafts.isEmpty && warnings.isEmpty) ? .imports : .review
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

    private func bindingKind(for itemId: UUID) -> Binding<NotesImportItemKind> {
        Binding(
            get: {
                previewItems.first(where: { $0.id == itemId })?.kind ?? .battery
            },
            set: { newValue in
                if let index = previewItems.firstIndex(where: { $0.id == itemId }) {
                    previewItems[index].kind = newValue
                }
            }
        )
    }

    private func bindingNote(for itemId: UUID) -> Binding<String> {
        Binding(
            get: {
                previewItems.first(where: { $0.id == itemId })?.note ?? ""
            },
            set: { newValue in
                if let index = previewItems.firstIndex(where: { $0.id == itemId }) {
                    previewItems[index].note = newValue
                }
            }
        )
    }

    private func bindingRejectedKind(for draftId: UUID) -> Binding<NotesImportItemKind> {
        Binding(
            get: {
                rejectedDrafts.first(where: { $0.id == draftId })?.kind ?? .battery
            },
            set: { newValue in
                if let index = rejectedDrafts.firstIndex(where: { $0.id == draftId }) {
                    rejectedDrafts[index].kind = newValue
                }
            }
        )
    }

    private func bindingRejectedDate(for draftId: UUID) -> Binding<Date> {
        Binding(
            get: {
                rejectedDrafts.first(where: { $0.id == draftId })?.timestamp ?? Date()
            },
            set: { newValue in
                if let index = rejectedDrafts.firstIndex(where: { $0.id == draftId }) {
                    rejectedDrafts[index].timestamp = newValue
                }
            }
        )
    }

    private func bindingRejectedNote(for draftId: UUID) -> Binding<String> {
        Binding(
            get: {
                rejectedDrafts.first(where: { $0.id == draftId })?.note ?? ""
            },
            set: { newValue in
                if let index = rejectedDrafts.firstIndex(where: { $0.id == draftId }) {
                    rejectedDrafts[index].note = newValue
                }
            }
        )
    }

    private func needsReview(_ item: NotesImportPreviewItem) -> Bool {
        item.resolvedTimestamp == nil
    }

    private func addRejectedDraftToImports(_ draftId: UUID) {
        guard let index = rejectedDrafts.firstIndex(where: { $0.id == draftId }) else { return }
        let draft = rejectedDrafts[index]
        let parsed = NotesImportParsedItem(
            kind: draft.kind,
            originalLine: draft.line,
            timestamp: draft.timestamp,
            parsedLine: draft.note.isEmpty ? nil : draft.note,
            timestampInferred: false
        )
        previewItems.append(NotesImportPreviewItem(parsed: parsed))
        previewItems.sort {
            ($0.resolvedTimestamp ?? .distantPast) > ($1.resolvedTimestamp ?? .distantPast)
        }
        rejectedDrafts.remove(at: index)
    }

    @ViewBuilder
    private func importItemCard(_ item: NotesImportPreviewItem) -> some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parsed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.originalLine)
                        .font(.subheadline)
                }

                HStack {
                    Picker("Target", selection: bindingKind(for: item.id)) {
                        Text("Battery").tag(NotesImportItemKind.battery)
                        Text("Issue").tag(NotesImportItemKind.issue)
                    }
                    .pickerStyle(.segmented)

                    if needsReview(item) {
                        Text("Review")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.orange.opacity(0.15))
                            )
                    }
                }

                DatePicker(
                    "Date & Time",
                    selection: bindingDate(for: item.id),
                    displayedComponents: [.date, .hourAndMinute]
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(
                        "Type notes",
                        text: bindingNote(for: item.id),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .note(item.id))
                }

                if item.timestampInferred {
                    Text("Time was inferred from date-only input.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotesImportView()
    }
}
