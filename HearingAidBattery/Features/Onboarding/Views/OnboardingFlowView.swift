//
//  OnboardingFlowView.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-03.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OnboardingFlowView: View {
    private enum Step: String, CaseIterable {
        case name
        case tracking
        case hearingAid
        case batteryPack
        case notifications
        case finish

        var index: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }

    private enum TrackingRole: String, CaseIterable, Identifiable {
        case myself = "self"
        case child = "child"
        case dependent = "dependent"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .myself: return "Myself"
            case .child: return "My child"
            case .dependent: return "Someone I care for"
            case .other: return "Other"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var activeSpaceSelection: ActiveSpaceSelectionService

    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false
    @AppStorage("onboarding.step") private var onboardingStepRaw: String = Step.name.rawValue
    @AppStorage("onboarding.displayName") private var displayName: String = ""
    @AppStorage("onboarding.roleHint") private var roleHintRaw: String = TrackingRole.myself.rawValue
    @AppStorage("onboarding.spaceId") private var onboardingSpaceIdString: String = ""

    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]
    @Query(sort: \BatteryPack.purchaseDate, order: .reverse) private var batteryPacks: [BatteryPack]

    @State private var showsAddPackSheet: Bool = false
    @State private var notificationEnabled: Bool = false
    @State private var expectedDeathWarningEnabled: Bool = true
    @State private var expectedDeathWarningHours: Int = 1
    @State private var expectedDeathWarningMinutes: Int = 0
    @State private var morningHeadsUpEnabled: Bool = true
    @State private var morningHour: Int = 8
    @State private var morningMinute: Int = 0
    @State private var showsNotificationConfigSheet: Bool = false
    @State private var errorMessage: String?
    @State private var showsFileImporter: Bool = false
    @State private var isImporting: Bool = false

    private let batteryPackService = BatteryPackService()
    private let notificationService = NotificationService()
    private let backupImportService = BackupImportService()

    private var step: Step {
        Step(rawValue: onboardingStepRaw) ?? .name
    }

    private var selectedRole: TrackingRole {
        TrackingRole(rawValue: roleHintRaw) ?? .myself
    }

    private var activeSpaceHearingAids: [HearingAid] {
        hearingAids.uniqueById().filter { $0.spaceId == activeSpaceSelection.activeSpaceId }
    }

    private var activeSpacePacks: [BatteryPack] {
        batteryPacks.uniqueById().filter { $0.spaceId == activeSpaceSelection.activeSpaceId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if step == .name {
                        welcomeHeader
                    }
                    onboardingHeader
                    CardRowContainer {
                        stepContent
                    }
                    onboardingNavigation
                }
                .screenContentPadding()
            }
            .scrollContentBackground(.hidden)
            .background(AppBackgroundView())
            .navigationTitle(step == .name ? "" : "Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            checkForSyncedData()
            loadNotificationState()
        }
        .onChange(of: hearingAids.count) {
            checkForSyncedData()
        }
        .sheet(isPresented: $showsAddPackSheet) {
            AddBatteryPackSheet(
                existingPacks: activeSpacePacks,
                previousPack: activeSpacePacks.sorted { $0.purchaseDate < $1.purchaseDate }.last,
                onSave: { batteryType, brand, purchaseDate, batteriesPerPack, numberOfPacks, priceAmount, currencyCode in
                    try batteryPackService.createBatteryPack(
                        batteryType: batteryType,
                        purchaseDate: purchaseDate,
                        batteriesPerPack: batteriesPerPack,
                        numberOfPacks: numberOfPacks,
                        priceAmount: priceAmount,
                        currencyCode: currencyCode,
                        brand: brand,
                        context: context
                    )
                    showsAddPackSheet = false
                },
                onCancel: { showsAddPackSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .sheet(isPresented: $showsNotificationConfigSheet) {
            NavigationStack {
                HearingAidNotificationSettingsView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .errorAlert(title: "Unable to Continue", message: $errorMessage)
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Could not read backup file."
                return
            }
            importBackup(data: data)
        case .failure:
            errorMessage = "Import failed."
        }
    }

    private func importBackup(data: Data) {
        isImporting = true
        do {
            _ = try backupImportService.importJSONData(
                data,
                context: context,
                spaceImportMode: .preserveBackupSpaces
            )
            // Import succeeded - mark onboarding complete and refresh
            activeSpaceSelection.refresh(context: context)
            onboardingCompleted = true
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
        isImporting = false
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .name:
            nameStep
        case .tracking:
            trackingStep
        case .hearingAid:
            hearingAidStep
        case .batteryPack:
            batteryPackStep
        case .notifications:
            notificationsStep
        case .finish:
            finishStep
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What should we call this space?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Your name", text: $displayName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            Divider()
                .padding(.vertical, 4)

            Text("Or restore from a backup")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showsFileImporter = true
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isImporting)
        }
    }

    private var trackingStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who are you tracking for?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Tracking For", selection: Binding(
                get: { selectedRole },
                set: { roleHintRaw = $0.rawValue }
            )) {
                ForEach(TrackingRole.allCases) { role in
                    Text(role.title).tag(role)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var hearingAidStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if activeSpaceHearingAids.isEmpty {
                Text("Add your first hearing aid.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Great. You added \(activeSpaceHearingAids.count) hearing aid\(activeSpaceHearingAids.count == 1 ? "" : "s").")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if activeSpaceHearingAids.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added Hearing Aids")
                        .font(.subheadline.weight(.semibold))
                    ForEach(activeSpaceHearingAids) { aid in
                        NavigationLink {
                            HearingAidDetailView(aid: aid)
                        } label: {
                            CardRowContainer {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(aid.name)
                                            .font(.subheadline.weight(.semibold))
                                        if let model = aid.model, model.isEmpty == false {
                                            Text(model)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    Text("Edit")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            NavigationLink {
                AddHearingAidView()
            } label: {
                Label("Add Hearing Aid", systemImage: "ear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
    }

    private var batteryPackStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if activeSpacePacks.isEmpty {
                Text("Add your first battery pack.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Great. You added \(activeSpacePacks.count) battery pack\(activeSpacePacks.count == 1 ? "" : "s").")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showsAddPackSheet = true
            } label: {
                Label("Add Battery Pack", systemImage: "shippingbox")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notification settings are optional during onboarding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(notificationEnabled ? "Notifications enabled." : "Notifications are currently off.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(notificationEnabled ? .green : .secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(summaryNotificationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Configure") {
                    showsNotificationConfigSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup complete. Here is your summary:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                summaryRow(title: "Display Name", value: displayName.trimmingCharacters(in: .whitespacesAndNewlines))
                summaryRow(title: "Tracking For", value: selectedRole.title)
                summaryRow(title: "Hearing Aids Added", value: "\(activeSpaceHearingAids.count)")
                summaryRow(title: "Battery Packs Added", value: "\(activeSpacePacks.count)")
                summaryRow(title: "Notifications", value: summaryNotificationText)
            }
        }
    }

    private var onboardingTitle: String {
        switch step {
        case .name: return "Step 1 of 6"
        case .tracking: return "Step 2 of 6"
        case .hearingAid: return "Step 3 of 6"
        case .batteryPack: return "Step 4 of 6"
        case .notifications: return "Step 5 of 6"
        case .finish: return "Step 6 of 6"
        }
    }

    private func syncWithExistingData() {
        loadNotificationState()
    }

    /// Checks if iCloud synced data with hearing aids. If so, skip onboarding entirely.
    private func checkForSyncedData() {
        let allAids = hearingAids.uniqueById()
        guard !allAids.isEmpty else { return }

        // Data synced from iCloud - use the first aid's space and complete onboarding
        if let firstAid = allAids.first {
            activeSpaceSelection.setCurrentSpace(firstAid.spaceId, context: context)
        }

        // Clear draft state and complete
        displayName = ""
        roleHintRaw = TrackingRole.myself.rawValue
        onboardingSpaceIdString = ""
        onboardingStepRaw = Step.name.rawValue
        onboardingCompleted = true
    }

    @discardableResult
    private func configureInitialSpace() -> Bool {
        do {
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = name.isEmpty ? "Personal" : name
            let space: Space

            // First, check if defaultSpaceId already exists (may have synced from iCloud)
            let defaultSpaceId = Space.defaultSpaceId
            let defaultDescriptor = FetchDescriptor<Space>(
                predicate: #Predicate<Space> { $0.id == defaultSpaceId }
            )
            let existingDefault = try context.fetch(defaultDescriptor).first

            if selectedRole == .myself {
                // For "myself" role, always use the default space ID
                if let existing = existingDefault {
                    existing.name = finalName
                    existing.roleHint = TrackingRole.myself.rawValue
                    space = existing
                } else {
                    let created = Space.makeDefaultSpace(name: finalName, roleHint: TrackingRole.myself.rawValue)
                    context.insert(created)
                    space = created
                }
            } else if let existingId = UUID(uuidString: onboardingSpaceIdString) {
                // User already created a space earlier in onboarding (going back/forth)
                let descriptor = FetchDescriptor<Space>(
                    predicate: #Predicate<Space> { $0.id == existingId }
                )
                if let existing = try context.fetch(descriptor).first {
                    existing.name = finalName
                    existing.roleHint = selectedRole.rawValue
                    space = existing
                } else {
                    // Space was deleted/not synced, create new with different ID
                    let created = Space(name: finalName, roleHint: selectedRole.rawValue)
                    context.insert(created)
                    space = created
                }
            } else {
                // Non-myself role, no existing onboarding space - create new
                // Use a new UUID (not defaultSpaceId) to avoid collisions with iCloud synced default
                let created = Space(name: finalName, roleHint: selectedRole.rawValue)
                context.insert(created)
                space = created
            }

            try context.save()
            onboardingSpaceIdString = space.id.uuidString
            activeSpaceSelection.setCurrentSpace(space.id, context: context)
            return true
        } catch {
            errorMessage = "Could not save space setup."
            return false
        }
    }

    private func loadNotificationState() {
        let settings = notificationService.loadOrCreateSettings(context: context)
        notificationEnabled = settings.isEnabled
        expectedDeathWarningEnabled = settings.isExpectedDeathWarningEnabled
        expectedDeathWarningHours = settings.expectedDeathWarningHours
        expectedDeathWarningMinutes = settings.expectedDeathWarningMinutes
        morningHeadsUpEnabled = settings.isMorningHeadsUpEnabled
        morningHour = settings.morningHour
        morningMinute = settings.morningMinute
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("HearTracker")
                .font(.largeTitle.weight(.bold))
            Text("Track battery life, predict replacements, and never get caught off guard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                Text(onboardingTitle)
                    .font(.headline)
            }
            ProgressView(value: Double(step.index + 1), total: Double(Step.allCases.count))
                .tint(.accentColor)
            Text("Set up your profile and preferences. You can always change these later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var onboardingNavigation: some View {
        HStack(spacing: 10) {
            if step != .name {
                Button("Back") {
                    moveToPreviousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)

            Button(nextButtonTitle) {
                moveToNextStep()
            }
            .buttonStyle(.borderedProminent)
            .disabled(canMoveForward == false)
        }
    }

    private var canMoveForward: Bool {
        switch step {
        case .name:
            return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .tracking:
            return true
        case .hearingAid:
            return activeSpaceHearingAids.isEmpty == false
        case .batteryPack:
            return true
        case .notifications:
            return true
        case .finish:
            return true
        }
    }

    private var nextButtonTitle: String {
        switch step {
        case .batteryPack:
            return activeSpacePacks.isEmpty ? "Skip for now" : "Continue"
        case .finish:
            return "Finish"
        default:
            return "Continue"
        }
    }

    private func moveToPreviousStep() {
        let previousIndex = max(0, step.index - 1)
        onboardingStepRaw = Step.allCases[previousIndex].rawValue
    }

    private func moveToNextStep() {
        switch step {
        case .name:
            onboardingStepRaw = Step.tracking.rawValue
        case .tracking:
            if configureInitialSpace() {
                onboardingStepRaw = Step.hearingAid.rawValue
            }
        case .hearingAid:
            onboardingStepRaw = Step.batteryPack.rawValue
        case .batteryPack:
            onboardingStepRaw = Step.notifications.rawValue
        case .notifications:
            onboardingStepRaw = Step.finish.rawValue
        case .finish:
            onboardingStepRaw = Step.name.rawValue
            onboardingSpaceIdString = ""
            onboardingCompleted = true
        }
    }

    private var summaryNotificationText: String {
        if notificationEnabled == false {
            return "Off"
        }
        let warning = expectedDeathWarningEnabled ? "Warning On" : "Warning Off"
        let morning = morningHeadsUpEnabled ? "Morning On" : "Morning Off"
        return "\(warning), \(morning)"
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value.isEmpty ? "Not set" : value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
