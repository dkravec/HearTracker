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
                        IssueCardRow(issue: issue, showsAidName: hearingAid == nil)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Issues")
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
                    issueLogService.saveFromSheet(
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

    var body: some View {
        CardRowContainer {
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

    let hearingAids: [HearingAid]
    let preselectedHearingAidId: UUID?
    let onSave: (Date, UUID?, String, Int?, String?) -> Void
    let onCancel: () -> Void

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
                        .textInputAutocapitalization(.never)
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
            .navigationTitle("New Issue")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmedIssue = issue.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            timestamp,
                            selectedHearingAidId,
                            trimmedIssue,
                            includesSeverity ? severityValue : nil,
                            trimmedNote.isEmpty ? nil : trimmedNote
                        )
                    }
                    .disabled(issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (hearingAids.isEmpty == false && selectedHearingAidId == nil))
                }
            }
            .onAppear {
                selectedHearingAidId = preselectedHearingAidId
            }
        }
    }
}
