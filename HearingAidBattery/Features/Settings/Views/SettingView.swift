//
//  SettingView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-28.
//

import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]
    @Query(sort: \NotificationModel.createdAt, order: .forward) private var notificationModels: [NotificationModel]

    @State private var showsDeleteAllDataAlert: Bool = false
    @State private var showsDeleteLogsSheet: Bool = false
    @State private var showsDeleteLogsAlert: Bool = false
    @State private var pendingDeleteLogsAidId: UUID?
    @State private var resultMessage: String?
    @State private var notificationsEnabled: Bool = false
    @State private var morningTime: Date = Date()
    @State private var hasLoadedNotificationSettings: Bool = false

    private let settingService = SettingService()
    private let notificationService = NotificationService()

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
                    let count = try settingService.deleteAllData(context: context)
                    resultMessage = "Deleted \(count) records."
                    Task {
                        await notificationService.rescheduleAll(context: context)
                    }
                } catch {
                    resultMessage = "Delete failed."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove hearing aids, battery logs, packs, and issues.")
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
                    Task {
                        await notificationService.rescheduleAll(context: context)
                    }
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
        .alert("Done", isPresented: Binding(
            get: { resultMessage != nil },
            set: { newValue in
                if !newValue { resultMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
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
        Task {
            await notificationService.rescheduleAll(context: context)
        }
    }

    private var deleteLogsAlertMessage: String {
        if let id = pendingDeleteLogsAidId, let aid = hearingAids.first(where: { $0.id == id }) {
            return "This only deletes battery logs for \(aid.name)."
        }
        return "This only deletes battery logs for all hearing aids."
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
