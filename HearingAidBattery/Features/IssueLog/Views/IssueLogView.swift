//
//  IssueLogView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI
import SwiftData

struct IssueLogListView: View {
    @Environment(\.modelContext) private var context
    let hearingAid: HearingAid?
    let hearingAids: [HearingAid]
    @Query private var issues: [IssueLog]

    @State private var showsAddIssueSheet: Bool = false

    private let issueLogService = IssueLogService()

    init(hearingAid: HearingAid? = nil, hearingAids: [HearingAid] = []) {
        self.hearingAid = hearingAid
        self.hearingAids = hearingAids
        if let hearingAid {
            let hearingAidId = hearingAid.id
            _issues = Query(
                filter: #Predicate<IssueLog> { $0.hearingAid?.id == hearingAidId },
                sort: \IssueLog.timestamp,
                order: .reverse
            )
        } else {
            _issues = Query(
                sort: \IssueLog.timestamp,
                order: .reverse
            )
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Issue Logs")

                if issues.isEmpty {
                    EmptyStateView(
                        title: "No Issues Logged",
                        systemImage: FeatureSymbols.issue,
                        message: "Issue tracking entries will appear here."
                    )
                } else {
                    ForEach(issues) { issue in
                        NavigableCardRow {
                            IssueLogDetailView(
                                issue: issue,
                                hearingAids: hearingAids,
                                issueLogService: issueLogService
                            )
                        } content: {
                            IssueCardRow(
                                issue: issue,
                                showsAidName: hearingAid == nil,
                                wrapsInCard: false
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Issues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Issue") {
                    showsAddIssueSheet = true
                }
            }
        }
        .sheet(isPresented: $showsAddIssueSheet) {
            AddIssueLogSheet(
                hearingAids: hearingAid == nil ? hearingAids : [],
                preselectedHearingAidId: hearingAid?.id ?? hearingAids.first?.id,
                onSave: { timestamp, hearingAidId, issue, severity, note in
                    try issueLogService.saveFromSheet(
                        aids: hearingAids,
                        singleAid: hearingAid,
                        hearingAidId: hearingAidId,
                        timestamp: timestamp,
                        issue: issue,
                        severity: severity,
                        note: note,
                        context: context
                    )
                    showsAddIssueSheet = false
                },
                onCancel: {
                    showsAddIssueSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .appBackground()
    }
}

struct IssueCardRow: View {
    let issue: IssueLog
    var showsAidName: Bool = true
    var wrapsInCard: Bool = true

    var body: some View {
        Group {
            if wrapsInCard {
                CardRowContainer {
                    rowContent
                }
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(issue.issue)
                    .font(.headline)
                Spacer(minLength: 8)
                Text(issue.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsAidName {
                Text(issue.hearingAid?.name ?? "Unknown Aid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let severity = issue.severity {
                Text("Severity: \(severity)/5")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let note = issue.note, note.isEmpty == false {
                Text(note)
                    .font(.subheadline)
            }
        }
    }
}

struct IssueLogDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let issue: IssueLog
    let hearingAids: [HearingAid]
    let issueLogService: IssueLogService

    @State private var showsEditSheet: Bool = false
    @State private var showsDeleteConfirm: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Issue")

                CardRowContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(issue.issue)
                            .font(.headline)
                        Text(issue.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(issue.hearingAid?.name ?? "Unknown Aid")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let severity = issue.severity {
                            Text("Severity: \(severity)/5")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let note = issue.note, note.isEmpty == false {
                            Divider()
                            Text(note)
                                .font(.subheadline)
                        }
                    }
                }

                CardRowContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Delete Issue", role: .destructive) {
                            showsDeleteConfirm = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Issue Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showsEditSheet = true
                }
            }
        }
        .appBackground()
        .sheet(isPresented: $showsEditSheet) {
            AddIssueLogSheet(
                hearingAids: hearingAids,
                preselectedHearingAidId: issue.hearingAid?.id,
                title: "Edit Issue",
                saveButtonTitle: "Save",
                initialTimestamp: issue.timestamp,
                initialIssue: issue.issue,
                initialSeverity: issue.severity,
                initialNote: issue.note ?? "",
                onSave: { timestamp, _, issueText, severity, note in
                    do {
                        try issueLogService.updateIssue(
                            issue,
                            timestamp: timestamp,
                            issue: issueText,
                            severity: severity,
                            note: note,
                            context: context
                        )
                        showsEditSheet = false
                    } catch {
                        errorMessage = "Could not save issue changes."
                    }
                },
                onCancel: {
                    showsEditSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .alert("Delete Issue?", isPresented: $showsDeleteConfirm) {
            Button("Delete", role: .destructive) {
                do {
                    try issueLogService.deleteIssue(issue, context: context)
                    dismiss()
                } catch {
                    errorMessage = "Could not delete issue."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .errorAlert(message: $errorMessage)
    }
}

struct IssueLogView: View {
    let hearingAid: HearingAid?
    let hearingAids: [HearingAid]

    init(hearingAid: HearingAid) {
        self.hearingAid = hearingAid
        self.hearingAids = []
    }

    init(hearingAids: [HearingAid]) {
        self.hearingAid = nil
        self.hearingAids = hearingAids
    }

    var body: some View {
        IssueLogListView(hearingAid: hearingAid, hearingAids: hearingAids)
    }
}

struct AddIssueLogSheet: View {
    @State private var timestamp: Date = Date()
    @State private var issue: String = ""
    @State private var includesSeverity: Bool = false
    @State private var severityValue: Int = 3
    @State private var note: String = ""
    @State private var selectedHearingAidId: UUID?
    @State private var errorMessage: String?

    let hearingAids: [HearingAid]
    let preselectedHearingAidId: UUID?
    let title: String
    let saveButtonTitle: String
    let initialTimestamp: Date
    let initialIssue: String
    let initialSeverity: Int?
    let initialNote: String
    let onSave: (Date, UUID?, String, Int?, String?) throws -> Void
    let onCancel: () -> Void

    init(
        hearingAids: [HearingAid],
        preselectedHearingAidId: UUID?,
        title: String = "New Issue",
        saveButtonTitle: String = "Save",
        initialTimestamp: Date = Date(),
        initialIssue: String = "",
        initialSeverity: Int? = nil,
        initialNote: String = "",
        onSave: @escaping (Date, UUID?, String, Int?, String?) throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.hearingAids = hearingAids
        self.preselectedHearingAidId = preselectedHearingAidId
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.initialTimestamp = initialTimestamp
        self.initialIssue = initialIssue
        self.initialSeverity = initialSeverity
        self.initialNote = initialNote
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Issue") {
                    DatePicker(
                        "Timestamp",
                        selection: $timestamp,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("What's the problem", text: $issue)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                    if hearingAids.isEmpty == false {
                        Picker("Hearing Aid", selection: $selectedHearingAidId) {
                            ForEach(hearingAids) { aid in
                                Text(aid.name).tag(Optional(aid.id))
                            }
                        }
                    }
                    Toggle("Include severity", isOn: $includesSeverity)
                    if includesSeverity {
                        Stepper("Severity: \(severityValue)", value: $severityValue, in: 1...5)
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonTitle) {
                        let trimmedIssue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        do {
                            try onSave(
                                timestamp,
                                selectedHearingAidId,
                                trimmedIssue,
                                includesSeverity ? severityValue : nil,
                                trimmedNote.isEmpty ? nil : trimmedNote
                            )
                        } catch {
                            errorMessage = "Could not save issue."
                        }
                    }
                    .disabled(issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (hearingAids.isEmpty == false && selectedHearingAidId == nil))
                }
            }
            .onAppear {
                timestamp = initialTimestamp
                issue = initialIssue
                note = initialNote
                includesSeverity = (initialSeverity != nil)
                severityValue = initialSeverity ?? 3
                selectedHearingAidId = preselectedHearingAidId
            }
            .errorAlert(title: "Unable to Save Issue", message: $errorMessage)
        }
    }
}
