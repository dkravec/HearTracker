import SwiftUI
import SwiftData

struct HearingAidNotificationSettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var settings: NotificationModel?
    @State private var activeAids: [HearingAid] = []
    @State private var batteryTypePreferences: [BatteryTypeNotificationPreference] = []
    @State private var showsPermissionAlert: Bool = false
    @State private var hasLoaded: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let settings, hasLoaded {
                    generalSection(settings: settings)

                    if settings.isEnabled {
                        alertsSection(settings: settings)
                        batteryPackSection(settings: settings)
                        perAidSection()
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("Notification Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .onAppear {
            loadData()
        }
        .onDisappear {
            saveData()
        }
        .alert("Notifications Disabled", isPresented: $showsPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable notifications for HearTracker in the system Settings app, then try again.")
        }
    }

    @ViewBuilder
    private func generalSection(settings: NotificationModel) -> some View {
        SectionHeaderView(title: "General")
        CardRowContainer {
            Toggle(isOn: Binding(
                get: { settings.isEnabled },
                set: { newValue in
                    if newValue {
                        requestPermissionAndSet(settings: settings)
                    } else {
                        settings.isEnabled = false
                    }
                }
            )) {
                Label("Enable Notifications", systemImage: "bell.badge.fill")
                    .font(.headline)
            }
        }
    }

    @ViewBuilder
    private func alertsSection(settings: NotificationModel) -> some View {
        SectionHeaderView(title: "Alerts")
        CardRowContainer {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { settings.isExpectedDeathWarningEnabled },
                    set: { settings.isExpectedDeathWarningEnabled = $0 }
                )) {
                    Label("Expected Death Warning", systemImage: "clock.badge.exclamationmark.fill")
                        .font(.headline)
                }

                if settings.isExpectedDeathWarningEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(
                            "Hours: \(settings.expectedDeathWarningHours)",
                            value: Binding(
                                get: { settings.expectedDeathWarningHours },
                                set: { settings.expectedDeathWarningHours = $0 }
                            ),
                            in: 0...48
                        )
                        Stepper(
                            "Minutes: \(settings.expectedDeathWarningMinutes)",
                            value: Binding(
                                get: { settings.expectedDeathWarningMinutes },
                                set: { settings.expectedDeathWarningMinutes = $0 }
                            ),
                            in: 0...59
                        )
                    }
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { settings.isMorningHeadsUpEnabled },
                    set: { settings.isMorningHeadsUpEnabled = $0 }
                )) {
                    Label("Morning Heads-Up", systemImage: "sun.max.fill")
                        .font(.headline)
                }

                if settings.isMorningHeadsUpEnabled {
                    DatePicker(
                        "Morning Heads-Up Time",
                        selection: Binding(
                            get: {
                                var components = DateComponents()
                                components.hour = settings.morningHour
                                components.minute = settings.morningMinute
                                return Calendar.current.date(from: components) ?? Date()
                            },
                            set: { date in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                settings.morningHour = components.hour ?? 8
                                settings.morningMinute = components.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func batteryPackSection(settings: NotificationModel) -> some View {
        SectionHeaderView(title: "Battery Packs")
        CardRowContainer {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { settings.isLowBatteryPackWarningEnabled },
                    set: { settings.isLowBatteryPackWarningEnabled = $0 }
                )) {
                    Label("Low Pack Warning", systemImage: "battery.25")
                        .font(.headline)
                }

                if settings.isLowBatteryPackWarningEnabled {
                    Stepper(
                        "Notify at or below: \(settings.lowBatteryPackThreshold)",
                        value: Binding(
                            get: { max(1, settings.lowBatteryPackThreshold) },
                            set: { settings.lowBatteryPackThreshold = max(1, $0) }
                        ),
                        in: 1...48
                    )

                    if batteryTypePreferences.isEmpty == false {
                        Divider()
                        ForEach(batteryTypePreferences) { preference in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(
                                    isOn: Binding(
                                        get: { preference.notificationsOn },
                                        set: { preference.notificationsOn = $0 }
                                    )
                                ) {
                                    Text("Type: \(preference.batteryType)")
                                        .font(.subheadline.weight(.semibold))
                                }

                                HStack(spacing: 8) {
                                    Text(preference.sentFinal ? "No-battery alert sent" : "No-battery alert pending")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer(minLength: 8)

                                    Button(role: .destructive) {
                                        deleteBatteryTypePreference(preference)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }

                            if preference.id != batteryTypePreferences.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func perAidSection() -> some View {
        SectionHeaderView(title: "Per Hearing Aid")
        if activeAids.isEmpty {
            EmptyStateView(
                title: "No Hearing Aids",
                systemImage: FeatureSymbols.hearingAid,
                message: "Add a hearing aid to configure notification preferences."
            )
        } else {
            CardRowContainer {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(activeAids) { aid in
                        Toggle(isOn: Binding(
                            get: { aid.notificationsEnabled },
                            set: { aid.notificationsEnabled = $0 }
                        )) {
                            Text(aid.name)
                                .font(.headline)
                        }

                        if aid.id != activeAids.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func loadData() {
        guard hasLoaded == false else { return }

        // Load or create notification settings
        var descriptor = FetchDescriptor<NotificationModel>(
            sortBy: [SortDescriptor(\NotificationModel.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            settings = existing
        } else {
            let newSettings = NotificationModel()
            context.insert(newSettings)
            try? context.save()
            settings = newSettings
        }

        // Load active hearing aids
        let aidDescriptor = FetchDescriptor<HearingAid>(
            predicate: #Predicate<HearingAid> { $0.retired == false },
            sortBy: [SortDescriptor(\HearingAid.createdAt, order: .reverse)]
        )
        activeAids = (try? context.fetch(aidDescriptor)) ?? []
        batteryTypePreferences = ensureBatteryTypePreferences()
        hasLoaded = true
    }

    private func requestPermissionAndSet(settings: NotificationModel) {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings()

            switch status.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                settings.isEnabled = true
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                settings.isEnabled = granted
                if !granted {
                    showsPermissionAlert = true
                }
            default:
                settings.isEnabled = false
                showsPermissionAlert = true
            }
        }
    }

    private func saveData() {
        guard let settings else { return }

        if settings.isExpectedDeathWarningEnabled,
           settings.expectedDeathWarningHours == 0,
           settings.expectedDeathWarningMinutes == 0 {
            settings.expectedDeathWarningHours = 1
        }

        if settings.lowBatteryPackThreshold < 1 {
            settings.lowBatteryPackThreshold = 1
        }

        try? context.save()

        Task { @MainActor in
            let service = NotificationService()
            await service.rescheduleAll(context: context)
        }
    }

    private func ensureBatteryTypePreferences() -> [BatteryTypeNotificationPreference] {
        let spaceId = SpaceService.currentSpaceId(context: context)
        let prefDescriptor = FetchDescriptor<BatteryTypeNotificationPreference>(
            predicate: #Predicate<BatteryTypeNotificationPreference> { $0.spaceId == spaceId },
            sortBy: [SortDescriptor(\BatteryTypeNotificationPreference.batteryType, order: .forward)]
        )
        var preferences = (try? context.fetch(prefDescriptor)) ?? []
        var prefKeys = Set(preferences.map { normalizedBatteryType($0.batteryType) })

        let packDescriptor = FetchDescriptor<BatteryPack>(
            predicate: #Predicate<BatteryPack> { $0.spaceId == spaceId },
            sortBy: [SortDescriptor(\BatteryPack.batteryType, order: .forward)]
        )
        let packs = (try? context.fetch(packDescriptor)) ?? []
        for pack in packs {
            let normalizedType = normalizedBatteryType(pack.batteryType)
            guard normalizedType.isEmpty == false else { continue }
            if prefKeys.contains(normalizedType) == false {
                let created = BatteryTypeNotificationPreference(
                    spaceId: spaceId,
                    batteryType: pack.batteryType.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                context.insert(created)
                preferences.append(created)
                prefKeys.insert(normalizedType)
            }
        }

        preferences.sort { $0.batteryType.localizedCaseInsensitiveCompare($1.batteryType) == .orderedAscending }
        try? context.save()
        return preferences
    }

    private func deleteBatteryTypePreference(_ preference: BatteryTypeNotificationPreference) {
        context.delete(preference)
        try? context.save()
        batteryTypePreferences.removeAll(where: { $0.id == preference.id })
    }

    private func normalizedBatteryType(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
