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
    @State private var issuePendingResolve: IssueLog?
    @State private var errorMessage: String?

    private let issueLogService = IssueLogService()

    init(hearingAid: HearingAid? = nil, hearingAids: [HearingAid] = []) {
        self.hearingAid = hearingAid
        self.hearingAids = hearingAids
        if let hearingAid {
            let hearingAidId = hearingAid.id
            let spaceId = hearingAid.spaceId
            _issues = Query(
                filter: #Predicate<IssueLog> { $0.hearingAid?.id == hearingAidId && $0.spaceId == spaceId },
                sort: \IssueLog.timestamp,
                order: .reverse
            )
        } else {
            let activeSpaceId = SpaceService.activeSpaceIdForQueries
            _issues = Query(
                filter: #Predicate<IssueLog> { $0.spaceId == activeSpaceId },
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
                    if unresolvedIssues.isEmpty {
                        CardRowContainer {
                            Text("No unresolved issues.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        SectionHeaderView(title: "Unresolved")
                        ForEach(unresolvedIssues) { issue in
                            issueRow(issue)
                        }
                    }

                    if resolvedIssues.isEmpty == false {
                        SectionHeaderView(title: "Resolved")
                            .padding(.top, 4)
                        ForEach(resolvedIssues) { issue in
                            issueRow(issue)
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
                Button {
                    showsAddIssueSheet = true
                } label: {
                    Label("Add Issue", systemImage: "plus")
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
        .sheet(item: $issuePendingResolve) { issue in
            ResolveIssueSheet(
                issue: issue,
                onSave: { resolvedAt, resolutionNote in
                    try issueLogService.resolveIssue(
                        issue,
                        resolvedAt: resolvedAt,
                        resolutionNote: resolutionNote,
                        context: context
                    )
                    issuePendingResolve = nil
                },
                onCancel: {
                    issuePendingResolve = nil
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .appBackground()
        .errorAlert(title: "Unable to Complete Action", message: $errorMessage)
    }

    private var unresolvedIssues: [IssueLog] {
        issues.filter { !$0.isResolved }
    }

    private var resolvedIssues: [IssueLog] {
        issues.filter { $0.isResolved }
    }

    @ViewBuilder
    private func issueRow(_ issue: IssueLog) -> some View {
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
        .contextMenu {
            if issue.isResolved {
                Button("Mark as Unresolved") {
                    do {
                        try issueLogService.unresolveIssue(issue, context: context)
                    } catch {
                        errorMessage = "Could not mark issue as unresolved."
                    }
                }
            } else {
                Button("Mark as Resolved") {
                    issuePendingResolve = issue
                }
            }
        }
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

            if issue.isResolved {
                Text("Resolved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
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
    @State private var showsResolveSheet: Bool = false
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

                SectionHeaderView(title: "Resolution")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(issue.isResolved ? "Resolved" : "Unresolved")
                            .font(.headline)
                            .foregroundStyle(issue.isResolved ? .green : .secondary)

                        if issue.isResolved {
                            if let resolvedAt = issue.resolvedAt {
                                Text("Resolved at: \(resolvedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let resolutionNote = issue.resolutionNote, resolutionNote.isEmpty == false {
                                Text(resolutionNote)
                                    .font(.subheadline)
                            }
                        } else {
                            Text("This issue is still open.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                CardRowContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        if issue.isResolved {
                            Button("Mark as Unresolved") {
                                do {
                                    try issueLogService.unresolveIssue(issue, context: context)
                                } catch {
                                    errorMessage = "Could not mark issue as unresolved."
                                }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Mark as Resolved") {
                                showsResolveSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

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
        .sheet(isPresented: $showsResolveSheet) {
            ResolveIssueSheet(
                issue: issue,
                onSave: { resolvedAt, resolutionNote in
                    do {
                        try issueLogService.resolveIssue(
                            issue,
                            resolvedAt: resolvedAt,
                            resolutionNote: resolutionNote,
                            context: context
                        )
                        showsResolveSheet = false
                    } catch {
                        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not resolve issue."
                    }
                },
                onCancel: {
                    showsResolveSheet = false
                }
            )
            .presentationDetents([.medium])
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Issue Summary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Describe the problem", text: $issue)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled()
                    }
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Additional Notes (Optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Add any extra details", text: $note, axis: .vertical)
                            .lineLimit(1...4)
                    }
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

private struct ResolveIssueSheet: View {
    @State private var resolvedAt: Date = Date()
    @State private var resolutionNote: String = ""
    @State private var errorMessage: String?

    let issue: IssueLog
    let onSave: (Date, String) throws -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Issue") {
                    Text(issue.issue)
                        .font(.headline)
                    Text(issue.hearingAid?.name ?? "Unknown Aid")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Resolution") {
                    DatePicker(
                        "Resolved At",
                        selection: $resolvedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolution Note (Optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("What was done to resolve it?", text: $resolutionNote, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
            }
            .navigationTitle("Resolve Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        do {
                            try onSave(resolvedAt, resolutionNote)
                        } catch {
                            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not resolve issue."
                        }
                    }
                }
            }
            .errorAlert(title: "Unable to Resolve Issue", message: $errorMessage)
        }
    }
}
