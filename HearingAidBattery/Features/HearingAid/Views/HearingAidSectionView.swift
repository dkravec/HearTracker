//
//  HearingAidSectionView.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-02.
//

import SwiftUI
import SwiftData

struct HearingAidSectionView: View {
    @Environment(\.modelContext) private var context
    @Query private var hearingAids: [HearingAid]
    @Query private var packs: [BatteryPack]

    @StateObject private var viewModel = HearingAidListViewModel()
    @State private var showsAddHearingAidSheet: Bool = false

    init() {
        let activeSpaceId = SpaceService.activeSpaceIdForQueries
        _hearingAids = Query(
            filter: #Predicate<HearingAid> { $0.spaceId == activeSpaceId },
            sort: \HearingAid.createdAt,
            order: .reverse
        )
        _packs = Query(
            filter: #Predicate<BatteryPack> { $0.spaceId == activeSpaceId },
            sort: \BatteryPack.purchaseDate,
            order: .reverse
        )
    }

    private var activeAids: [HearingAid] {
        viewModel.activeAids(from: hearingAids)
    }

    private var retiredAids: [HearingAid] {
        viewModel.retiredAids(from: hearingAids)
    }

    private var availablePacks: [BatteryPack] {
        packs.filter { $0.quantityRemaining > 0 && $0.isDone == false }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Hearing Aids")

                if activeAids.isEmpty {
                    EmptyStateView(
                        title: "No Hearing Aids",
                        systemImage: FeatureSymbols.hearingAid,
                        message: "Add a hearing aid to start tracking battery changes."
                    )
                } else {
                    ForEach(activeAids) { aid in
                        HearingAidCardRow(
                            aid: aid,
                            onLogTapped: { viewModel.beginLog(for: aid) }
                        )
                    }
                }

                if retiredAids.isEmpty == false {
                    SectionHeaderView(title: "Retired")
                        .padding(.top, 8)

                    ForEach(retiredAids) { aid in
                        HearingAidCardRow(
                            aid: aid,
                            onLogTapped: { viewModel.beginLog(for: aid) }
                        )
                    }
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("Hearing Aids")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showsAddHearingAidSheet = true
                } label: {
                    Label("Add Hearing Aid", systemImage: "plus")
                }
            }
        }
        .appBackground()
        .sheet(isPresented: $showsAddHearingAidSheet) {
            NavigationStack {
                AddHearingAidView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
        .sheet(isPresented: $viewModel.showsLogSheet) {
            if viewModel.resolvedAid(from: hearingAids) != nil {
                BatteryLogSheet(
                    note: $viewModel.logNote,
                    timestamp: $viewModel.logTimestamp,
                    selectedPackId: $viewModel.selectedPackId,
                    availablePacks: availablePacks,
                    onSave: { timestamp, note in
                        if let currentAid = viewModel.resolvedAid(from: hearingAids) {
                            viewModel.saveLog(for: currentAid, timestamp: timestamp, note: note, context: context)
                        }
                    },
                    onCancel: {
                        viewModel.endLog()
                    },
                    activeAids: hearingAids,
                    selectedAidId: $viewModel.selectedLogAidId
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .appBackground()
            }
        }
        .errorAlert(title: "Unable to Save", message: $viewModel.errorMessage)
    }
}

struct HearingAidCardRow: View {
    let aid: HearingAid
    let onLogTapped: () -> Void

    var body: some View {
        NavigationLink {
            HearingAidDetailView(aid: aid)
        } label: {
            CardRowContainer {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(aid.name)
                            .font(.headline)

                        if let model = aid.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                            Text(model)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let batteryType = aid.batteryType?.trimmingCharacters(in: .whitespacesAndNewlines), !batteryType.isEmpty {
                            Text("Type \(batteryType)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("\((aid.logs ?? []).count) changes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button("Log") {
                        onLogTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Log battery change for \(aid.name)")
                }
            }
        }
        .buttonStyle(.plain)
    }
}
