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
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]
    @Query(sort: \NotificationModel.createdAt, order: .forward) private var notificationModels: [NotificationModel]

    @State private var showsDeleteAllDataAlert: Bool = false
    @State private var showsDeleteLogsSheet: Bool = false
    @State private var showsDeleteLogsAlert: Bool = false
    @State private var showsImportBackupAlert: Bool = false
    @State private var showsImportConflictResolver: Bool = false
    @State private var showsFileImporter: Bool = false
    @State private var showsFileExporter: Bool = false
    @State private var pendingDeleteLogsAidId: UUID?
    @State private var pendingImportData: Data?
    @State private var importConflictAnalysis: BackupIssueLinkConflictAnalysis?
    @State private var issueLinkResolutions: [UUID: UUID?] = [:]
    @State private var exportDocument: BackupJSONDocument?
    @State private var exportFilename: String = "HearTrackerr_Backup_v1"
    @State private var resultMessage: String?
    @State private var notificationsEnabled: Bool = false
    @State private var morningTime: Date = Date()
    @State private var hasLoadedNotificationSettings: Bool = false

    private let settingService = SettingService()
    private let notificationService = NotificationService()
    private let backupExportService = BackupExportService()
    private let backupImportService = BackupImportService()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "General")
                CardRowContainer {
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

                SectionHeaderView(title: "Data")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsNavigationRow(
                            title: "Notes Import",
                            subtitle: "Paste and preview note history",
                            systemImage: "square.and.arrow.down.fill"
                        ) {
                            NotesImportView()
                        }

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

                SectionHeaderView(title: "Notifications")
                CardRowContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Enable Notifications", systemImage: "bell.badge.fill")
                                .font(.headline)
                        }

                        Divider()

                        DatePicker(
                            "Morning Heads-Up Time",
                            selection: $morningTime,
                            displayedComponents: .hourAndMinute
                        )
                        .disabled(notificationsEnabled == false)
                        .opacity(notificationsEnabled ? 1.0 : 0.55)
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
                            showsDeleteAllDataAlert = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .onAppear {
            loadNotificationSettings()
        }
        .onChange(of: notificationsEnabled) {
            persistNotificationSettingsAfterToggle()
        }
        .onChange(of: morningTime) {
            persistNotificationSettings()
        }
        .alert("Delete All Data?", isPresented: $showsDeleteAllDataAlert) {
            Button("Delete", role: .destructive) {
                do {
                    let summary = try settingService.deleteAllData(context: context)
                    resultMessage = deleteAllSummaryText(summary)
                    rescheduleNotifications()
                } catch {
                    resultMessage = "Delete failed."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove hearing aids, battery logs, packs, and issues.")
        }
        .alert("Import Backup?", isPresented: $showsImportBackupAlert) {
            Button("Import", role: .destructive) {
                performBackupImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
        } message: {
            Text("This will replace all existing data.")
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
            .background(AppBackgroundView())
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
                pendingImportData = data
                showsImportBackupAlert = true
            case .failure:
                resultMessage = "Import failed."
            }
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
                        },
                        onImport: {
                            performResolvedBackupImport()
                        }
                    )
                }
            } else {
                EmptyView()
            }
        }
    }

    private var activeAids: [HearingAid] {
        hearingAids.filter { !$0.retired }
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

    private func loadNotificationSettings() {
        let settings = notificationModels.first ?? notificationService.loadOrCreateSettings(context: context)
        notificationsEnabled = settings.isEnabled

        var components = DateComponents()
        components.hour = settings.morningHour
        components.minute = settings.morningMinute
        morningTime = Calendar.current.date(from: components) ?? Date()
        hasLoadedNotificationSettings = true
    }

    private func persistNotificationSettingsAfterToggle() {
        guard hasLoadedNotificationSettings else { return }
        if notificationsEnabled == false {
            persistNotificationSettings()
            return
        }

        Task {
            let granted = await notificationService.requestPermissionIfNeeded()
            guard granted else {
                notificationsEnabled = false
                persistNotificationSettings()
                resultMessage = "Notifications are disabled. Enable them in iOS Settings to use reminders."
                return
            }
            persistNotificationSettings()
        }
    }

    private func persistNotificationSettings() {
        guard hasLoadedNotificationSettings else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
        notificationService.saveSettings(
            isEnabled: notificationsEnabled,
            morningHour: components.hour ?? 8,
            morningMinute: components.minute ?? 0,
            context: context
        )
        rescheduleNotifications()
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

    private func exportBackup() {
        do {
            let data = try backupExportService.exportJSONData(context: context)
            exportDocument = BackupJSONDocument(data: data)
            exportFilename = "HearTrackerr_Backup_v1_\(timestampForFilename())"
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

            importBackupData(importData)
            clearImportConflictState()
        } catch let error as BackupImportService.BackupImportError {
            setImportFailureMessage(error)
            clearImportConflictState()
        } catch {
            resultMessage = "Import failed."
            clearImportConflictState()
        }
        pendingImportData = nil
    }

    private func performResolvedBackupImport() {
        guard let importData = pendingImportData else { return }
        importBackupData(importData, issueLogLinkedBatteryLogOverrides: issueLinkResolutions)
        clearImportConflictState()
        pendingImportData = nil
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
        issueLogLinkedBatteryLogOverrides: [UUID: UUID?] = [:]
    ) {
        do {
            let summary = try backupImportService.importJSONData(
                data,
                context: context,
                issueLogLinkedBatteryLogOverrides: issueLogLinkedBatteryLogOverrides
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

    private func rescheduleNotifications() {
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

    private func settingsNavigationRow<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            settingsRowLabel(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
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
                            Text("HearTrackerr")
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
