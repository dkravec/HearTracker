//
//  SettingView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var activeSpaceSelection: ActiveSpaceSelectionService
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false
    @AppStorage("onboarding.step") private var onboardingStepRaw: String = "name"
    @AppStorage("onboarding.spaceId") private var onboardingSpaceIdString: String = ""
    @Query private var hearingAids: [HearingAid]
    @Query(sort: \Space.createdAt, order: .forward) private var spaces: [Space]

    @State private var showsDeleteCurrentSpaceDataAlert: Bool = false
    @State private var showsDeleteAllDataAlert: Bool = false
    @State private var showsDeleteLogsSheet: Bool = false
    @State private var showsDeleteLogsAlert: Bool = false
    @State private var showsImportBackupAlert: Bool = false
    @State private var showsImportModeDialog: Bool = false
    @State private var showsImportSpaceMappingSheet: Bool = false
    @State private var showsImportConflictResolver: Bool = false
    @State private var showsFileImporter: Bool = false
    @State private var showsFileExporter: Bool = false
    @State private var showsSpaceSwitcher: Bool = false
    @State private var pendingDeleteLogsAidId: UUID?
    @State private var pendingImportData: Data?
    @State private var pendingImportSpaces: [SpaceDTO_v1] = []
    @State private var importSpaceTargetSelection: [UUID: String] = [:]
    @State private var pendingImportSpaceMode: BackupImportService.SpaceImportMode = .preserveBackupSpaces
    @State private var importConflictAnalysis: BackupIssueLinkConflictAnalysis?
    @State private var issueLinkResolutions: [UUID: UUID?] = [:]
    @State private var exportDocument: BackupJSONDocument?
    @State private var exportFilename: String = "HearTracker_Backup_v1"
    @State private var resultMessage: String?

    private let settingService = SettingService()
    private let notificationService = NotificationService()
    private let backupExportService = BackupExportService()
    private let backupImportService = BackupImportService()

    init() {
        let activeSpaceId = SpaceService.activeSpaceIdForQueries
        _hearingAids = Query(
            filter: #Predicate<HearingAid> { $0.spaceId == activeSpaceId },
            sort: \HearingAid.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "General")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            HearingAidNotificationSettingsView()
                        } label: {
                            settingsRowLabel(
                                title: "Notifications",
                                subtitle: "General, alerts, and per-device toggles",
                                systemImage: "bell.badge.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider()

                        settingsActionRow(
                            title: "Switch Person",
                            subtitle: currentSpaceName,
                            systemImage: "person.2.fill"
                        ) {
                            showsSpaceSwitcher = true
                        }

                        Divider()

                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsRowLabel(
                                title: "About",
                                subtitle: "Version, build, website",
                                systemImage: "info.circle.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionHeaderView(title: "Data")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            NotesImportView()
                        } label: {
                            settingsRowLabel(
                                title: "Notes Import",
                                subtitle: "Paste and preview note history",
                                systemImage: "square.and.arrow.down.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider()

                        settingsActionRow(
                            title: "Export Backup",
                            subtitle: "Save all data to JSON",
                            systemImage: "square.and.arrow.up.fill"
                        ) {
                            exportBackup()
                        }

                        Divider()

                        settingsActionRow(
                            title: "Import Backup",
                            subtitle: "Replace all data from JSON",
                            systemImage: "square.and.arrow.down.on.square.fill"
                        ) {
                            showsFileImporter = true
                        }
                    }
                }

                SectionHeaderView(title: "Danger Zone")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(role: .destructive) {
                            showsDeleteLogsSheet = true
                        } label: {
                            Label("Delete Battery Logs", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()

                        Button(role: .destructive) {
                            showsDeleteCurrentSpaceDataAlert = true
                        } label: {
                            Label("Delete Current Space", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()

                        Button(role: .destructive) {
                            showsDeleteAllDataAlert = true
                        } label: {
                            Label("Delete All Spaces Data", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .alert("Delete Current Space?", isPresented: $showsDeleteCurrentSpaceDataAlert) {
            Button("Delete", role: .destructive) {
                do {
                    let result = try settingService.deleteCurrentSpaceData(context: context)
                    resultMessage = deleteAllSummaryText(result.summary)

                    if let nextSpaceId = result.nextSpaceId {
                        activeSpaceSelection.setCurrentSpace(nextSpaceId, context: context)
                    } else {
                        resetOnboardingProgress()
                    }
                    rescheduleNotifications(refreshSpaceSelection: false)
                } catch {
                    resultMessage = "Delete failed."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes this space and its hearing aids, battery logs, packs, and issues.")
        }
        .alert("Delete All Spaces Data?", isPresented: $showsDeleteAllDataAlert) {
            Button("Delete", role: .destructive) {
                do {
                    let summary = try settingService.deleteAllData(context: context)
                    resultMessage = deleteAllSummaryText(summary)
                    resetOnboardingProgress()
                    rescheduleNotifications(refreshSpaceSelection: false)
                } catch {
                    resultMessage = "Delete failed."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all spaces, hearing aids, battery logs, packs, issues, and notification settings.")
        }
        .alert("Import Backup?", isPresented: $showsImportBackupAlert) {
            Button("Import", role: .destructive) {
                performBackupImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
                pendingImportSpaces = []
                importSpaceTargetSelection = [:]
                pendingImportSpaceMode = .preserveBackupSpaces
            }
        } message: {
            Text("This will replace all existing data.\nDestination: \(importDestinationText)")
        }
        .confirmationDialog("Import Destination", isPresented: $showsImportModeDialog, titleVisibility: .visible) {
            Button("Import Into Current Space (\(currentSpaceName))", role: .destructive) {
                pendingImportSpaceMode = .importIntoCurrentSpace(activeSpaceSelection.activeSpaceId)
                presentImportBackupAlert()
            }
            Button("Map/Create Spaces") {
                resetImportSpaceTargetSelection()
                DispatchQueue.main.async {
                    showsImportSpaceMappingSheet = true
                }
            }
            Button("Preserve Backup Spaces (Auto)") {
                pendingImportSpaceMode = .preserveBackupSpaces
                presentImportBackupAlert()
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
                pendingImportSpaces = []
                importSpaceTargetSelection = [:]
            }
        } message: {
            Text("Choose how imported data should be assigned to spaces.")
        }
        .sheet(isPresented: $showsDeleteLogsSheet) {
            NavigationStack {
                List {
                    Section("Choose Scope") {
                        Button("All Hearing Aids") {
                            pendingDeleteLogsAidId = nil
                            showsDeleteLogsSheet = false
                            showsDeleteLogsAlert = true
                        }
                        .foregroundStyle(.red)

                        ForEach(activeAids) { aid in
                            Button(aid.name) {
                                pendingDeleteLogsAidId = aid.id
                                showsDeleteLogsSheet = false
                                showsDeleteLogsAlert = true
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Delete Battery Logs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showsDeleteLogsSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .alert("Delete Battery Logs?", isPresented: $showsDeleteLogsAlert) {
            Button("Delete", role: .destructive) {
                do {
                    let count = try settingService.deleteBatteryLogs(for: pendingDeleteLogsAidId, context: context)
                    resultMessage = "Deleted \(count) battery logs."
                    rescheduleNotifications()
                } catch {
                    resultMessage = "Delete failed."
                }
                pendingDeleteLogsAidId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteLogsAidId = nil
            }
        } message: {
            Text(deleteLogsAlertMessage)
        }
        .alert(resultAlertTitle, isPresented: Binding(
            get: { resultMessage != nil },
            set: { newValue in
                if !newValue { resultMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .fileExporter(
            isPresented: $showsFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                resultMessage = "Backup exported."
            case .failure:
                resultMessage = "Export failed."
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer {
                    if access { url.stopAccessingSecurityScopedResource() }
                }
                guard let data = try? Data(contentsOf: url) else {
                    resultMessage = "Import failed."
                    return
                }
                do {
                    pendingImportSpaces = try backupImportService.previewSpaces(in: data)
                    pendingImportData = data
                    showsImportModeDialog = true
                } catch let error as BackupImportService.BackupImportError {
                    setImportFailureMessage(error)
                } catch {
                    resultMessage = "Import failed."
                }
            case .failure:
                resultMessage = "Import failed."
            }
        }
        .sheet(isPresented: $showsImportSpaceMappingSheet) {
            ImportSpaceMappingSheet(
                backupSpaces: pendingImportSpaces,
                existingSpaces: spaces,
                selections: $importSpaceTargetSelection,
                onCancel: {
                    showsImportSpaceMappingSheet = false
                    pendingImportData = nil
                    pendingImportSpaces = []
                    importSpaceTargetSelection = [:]
                },
                onImport: {
                    pendingImportSpaceMode = .map(buildImportSpaceMapping())
                    showsImportSpaceMappingSheet = false
                    presentImportBackupAlert()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .sheet(isPresented: $showsImportConflictResolver) {
            if let analysis = importConflictAnalysis {
                NavigationStack {
                    BackupImportConflictResolverView(
                        analysis: analysis,
                        resolutions: $issueLinkResolutions,
                        onCancel: {
                            clearImportConflictState()
                            pendingImportData = nil
                            pendingImportSpaces = []
                            importSpaceTargetSelection = [:]
                            pendingImportSpaceMode = .preserveBackupSpaces
                        },
                        onImport: {
                            performResolvedBackupImport()
                        }
                    )
                }
                .appBackground()
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showsSpaceSwitcher) {
            SpaceSwitcherSheet(
                spaces: spaces,
                activeSpaceId: activeSpaceSelection.activeSpaceId,
                onSelect: { space in
                    activeSpaceSelection.setCurrentSpace(space.id, context: context)
                    showsSpaceSwitcher = false
                },
                onCreate: { name, roleHint in
                    do {
                        let created = try SpaceService.createSpace(name: name, roleHint: roleHint, context: context)
                        activeSpaceSelection.setCurrentSpace(created.id, context: context)
                        showsSpaceSwitcher = false
                    } catch {
                        resultMessage = "Could not create person space."
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
    }

    private var activeAids: [HearingAid] {
        hearingAids.filter { !$0.retired }
    }

    private var currentSpaceName: String {
        spaces.first(where: { $0.id == activeSpaceSelection.activeSpaceId })?.name ?? "Personal"
    }

    private func settingsRowLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var deleteLogsAlertMessage: String {
        if let id = pendingDeleteLogsAidId, let aid = hearingAids.first(where: { $0.id == id }) {
            return "This only deletes battery logs for \(aid.name)."
        }
        return "This only deletes battery logs for all hearing aids."
    }

    private var resultAlertTitle: String {
        guard let resultMessage else { return "Result" }
        return resultMessage.lowercased().contains("failed") ? "Failed" : "Done"
    }

    private var importDestinationText: String {
        switch pendingImportSpaceMode {
        case .preserveBackupSpaces:
            return "Preserve backup spaces"
        case .importIntoCurrentSpace:
            return "Current space (\(currentSpaceName))"
        case .map:
            return "Mapped spaces"
        }
    }

    private func exportBackup() {
        do {
            let data = try backupExportService.exportJSONData(context: context)
            exportDocument = BackupJSONDocument(data: data)
            exportFilename = "HearTracker_Backup_v1_\(timestampForFilename())"
            showsFileExporter = true
        } catch {
            resultMessage = "Export failed."
        }
    }

    private func performBackupImport() {
        guard let importData = pendingImportData else { return }
        do {
            let analysis = try backupImportService.analyzeIssueLinkConflicts(in: importData)
            if analysis.conflicts.isEmpty == false {
                importConflictAnalysis = analysis
                issueLinkResolutions = Dictionary(uniqueKeysWithValues: analysis.conflicts.map { ($0.issueLogId, nil) })
                showsImportConflictResolver = true
                return
            }

            importBackupData(importData, spaceImportMode: pendingImportSpaceMode)
            clearImportConflictState()
        } catch let error as BackupImportService.BackupImportError {
            setImportFailureMessage(error)
            clearImportConflictState()
        } catch {
            resultMessage = "Import failed."
            clearImportConflictState()
        }
        pendingImportData = nil
        pendingImportSpaces = []
        importSpaceTargetSelection = [:]
        pendingImportSpaceMode = .preserveBackupSpaces
    }

    private func performResolvedBackupImport() {
        guard let importData = pendingImportData else { return }
        importBackupData(
            importData,
            issueLogLinkedBatteryLogOverrides: issueLinkResolutions,
            spaceImportMode: pendingImportSpaceMode
        )
        clearImportConflictState()
        pendingImportData = nil
        pendingImportSpaces = []
        importSpaceTargetSelection = [:]
        pendingImportSpaceMode = .preserveBackupSpaces
    }

    private func timestampForFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    private func deleteAllSummaryText(_ summary: DeleteAllDataSummary) -> String {
        """
        Deleted \(summary.total) records:
        \(summary.spaces) spaces
        \(summary.hearingAids) hearing aids
        \(summary.batteryLogs) battery logs
        \(summary.batteryPacks) battery packs
        \(summary.issueLogs) issue logs
        \(summary.notifications) notification settings
        """
    }

    private func importSummaryText(_ summary: BackupImportSummary) -> String {
        """
        Backup imported:
        \(summary.hearingAids) hearing aids
        \(summary.batteryLogs) battery logs
        \(summary.batteryPacks) battery packs
        \(summary.issueLogs) issue logs
        \(summary.notifications) notification settings
        """
    }

    private func clearImportConflictState() {
        showsImportConflictResolver = false
        importConflictAnalysis = nil
        issueLinkResolutions = [:]
    }

    private func importBackupData(
        _ data: Data,
        issueLogLinkedBatteryLogOverrides: [UUID: UUID?] = [:],
        spaceImportMode: BackupImportService.SpaceImportMode = .preserveBackupSpaces
    ) {
        do {
            let summary = try backupImportService.importJSONData(
                data,
                context: context,
                issueLogLinkedBatteryLogOverrides: issueLogLinkedBatteryLogOverrides,
                spaceImportMode: spaceImportMode
            )
            resultMessage = importSummaryText(summary)
            rescheduleNotifications()
        } catch let error as BackupImportService.BackupImportError {
            setImportFailureMessage(error)
        } catch {
            resultMessage = "Import failed."
        }
    }

    private func setImportFailureMessage(_ error: BackupImportService.BackupImportError) {
        resultMessage = "Import failed.\n\(importErrorText(error))"
    }

    private func importErrorText(_ error: BackupImportService.BackupImportError) -> String {
        switch error {
        case .unsupportedBackupFormatVersion(let version):
            return "Unsupported backup format version: \(version)."
        case .unsupportedModelVersion(let model, let version):
            return "Unsupported \(model) model version: \(version)."
        case .decodingFailed:
            return "The file could not be decoded."
        case .duplicateModelID(let model, let id):
            return "Duplicate ID in \(model): \(id.uuidString)."
        case .missingRequiredReference(let model, let field, let id):
            return "Missing \(field) for \(model) record \(id.uuidString)."
        case .unresolvedReference(let model, let field, let id):
            return "Unresolved \(field) for \(model) record \(id.uuidString)."
        }
    }

    private func resetOnboardingProgress() {
        onboardingStepRaw = "name"
        onboardingSpaceIdString = ""
        onboardingCompleted = false
    }

    private func presentImportBackupAlert() {
        DispatchQueue.main.async {
            showsImportBackupAlert = true
        }
    }

    private func resetImportSpaceTargetSelection() {
        var defaults: [UUID: String] = [:]
        for source in pendingImportSpaces {
            if spaces.contains(where: { $0.id == source.id }) {
                defaults[source.id] = source.id.uuidString
            } else {
                defaults[source.id] = ImportSpaceMappingSheet.createToken
            }
        }
        importSpaceTargetSelection = defaults
    }

    private func buildImportSpaceMapping() -> [UUID: BackupImportService.SpaceTarget] {
        var mapping: [UUID: BackupImportService.SpaceTarget] = [:]
        for source in pendingImportSpaces {
            let selection = importSpaceTargetSelection[source.id] ?? ImportSpaceMappingSheet.createToken
            if let targetId = UUID(uuidString: selection) {
                mapping[source.id] = .existing(targetId)
            } else {
                mapping[source.id] = .create(
                    name: source.name,
                    roleHint: source.roleHint,
                    createdAt: source.createdAt
                )
            }
        }
        return mapping
    }

    private func rescheduleNotifications(refreshSpaceSelection: Bool = true) {
        if refreshSpaceSelection {
            activeSpaceSelection.refresh(context: context)
        }
        Task {
            await notificationService.rescheduleAll(context: context)
        }
    }

    private func settingsActionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsRowLabel(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

}

private struct SpaceSwitcherSheet: View {
    private enum RoleOption: String, CaseIterable, Identifiable {
        case selfRole = "self"
        case child = "child"
        case dependent = "dependent"
        case other = "other"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .selfRole: return "Myself"
            case .child: return "My child"
            case .dependent: return "Someone I care for"
            case .other: return "Other"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let spaces: [Space]
    let activeSpaceId: UUID
    let onSelect: (Space) -> Void
    let onCreate: (String, String) -> Void

    @State private var showsCreate: Bool = false
    @State private var newName: String = ""
    @State private var roleOption: RoleOption = .other

    var body: some View {
        NavigationStack {
            List {
                Section("People") {
                    ForEach(spaces) { space in
                        Button {
                            onSelect(space)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(space.name)
                                        .foregroundStyle(.primary)
                                    Text(space.roleHint.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                if space.id == activeSpaceId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Switch Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Person") {
                        showsCreate = true
                    }
                }
            }
        }
        .sheet(isPresented: $showsCreate) {
            NavigationStack {
                Form {
                    Section("Person") {
                        TextField("Name", text: $newName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        Picker("Tracking For", selection: $roleOption) {
                            ForEach(RoleOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    }
                }
                .navigationTitle("Add Person")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showsCreate = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            onCreate(newName, roleOption.rawValue)
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
    }
}

private struct ImportSpaceMappingSheet: View {
    static let createToken = "create-new-space"

    let backupSpaces: [SpaceDTO_v1]
    let existingSpaces: [Space]
    @Binding var selections: [UUID: String]
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if backupSpaces.isEmpty {
                    Section {
                        Text("No spaces found in this backup.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Map Backup Spaces") {
                        ForEach(backupSpaces, id: \.id) { source in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(source.name)
                                    .font(.headline)
                                Picker("Destination", selection: binding(for: source.id)) {
                                    Text("Create New Space").tag(Self.createToken)
                                    ForEach(existingSpaces, id: \.id) { existing in
                                        Text(existing.name).tag(existing.id.uuidString)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Import Space Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onImport()
                    }
                    .disabled(backupSpaces.isEmpty)
                }
            }
        }
    }

    private func binding(for sourceSpaceId: UUID) -> Binding<String> {
        Binding(
            get: { selections[sourceSpaceId] ?? Self.createToken },
            set: { selections[sourceSpaceId] = $0 }
        )
    }
}

private struct BackupImportConflictResolverView: View {
    let analysis: BackupIssueLinkConflictAnalysis
    @Binding var resolutions: [UUID: UUID?]
    let onCancel: () -> Void
    let onImport: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List {
            Section {
                Text("Some issue logs link to battery logs that are not present in this backup. Choose a replacement log for each issue, or select Unlink.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Unresolved Links") {
                ForEach(analysis.conflicts) { conflict in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(conflict.issueText)
                            .font(.headline)
                        Text(conflictSubtitle(conflict))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Picker("Linked Battery Log", selection: selectionBinding(for: conflict.issueLogId)) {
                            Text("Unlink").tag(Optional<UUID>.none)
                            ForEach(analysis.candidates) { candidate in
                                Text(candidateLabel(candidate)).tag(Optional(candidate.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Resolve Import Links")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Import") {
                    onImport()
                }
            }
        }
    }

    private func selectionBinding(for issueLogId: UUID) -> Binding<UUID?> {
        Binding<UUID?>(
            get: { resolutions[issueLogId] ?? nil },
            set: { resolutions[issueLogId] = $0 }
        )
    }

    private func conflictSubtitle(_ conflict: BackupIssueLinkConflict) -> String {
        let timestamp = Self.dateFormatter.string(from: conflict.issueTimestamp)
        if let hearingAidName = conflict.hearingAidName {
            return "\(hearingAidName) • \(timestamp)\nMissing link: \(conflict.missingLinkedBatteryLogId.uuidString)"
        }
        return "\(timestamp)\nMissing link: \(conflict.missingLinkedBatteryLogId.uuidString)"
    }

    private func candidateLabel(_ candidate: BackupIssueLinkCandidate) -> String {
        let timestamp = Self.dateFormatter.string(from: candidate.timestamp)
        if let hearingAidName = candidate.hearingAidName {
            return "\(hearingAidName) • \(timestamp)"
        }
        return timestamp
    }
}

private struct AboutView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                CardRowContainer {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HearTracker")
                                .font(.headline)
                            Text("Hearing Aid Battery")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SectionHeaderView(title: "App")
                CardRowContainer {
                    VStack(spacing: 10) {
                        aboutRow(title: "Version", value: appVersion)
                        Divider()
                        aboutRow(title: "Build", value: appBuild)
                    }
                }

                SectionHeaderView(title: "Website")
                CardRowContainer {
                    Link(destination: URL(string: "https://hear.trackerr.ca")!) {
                        HStack {
                            Label("hear.trackerr.ca", systemImage: "globe")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview {
    NavigationStack {
        SettingView()
    }
}
