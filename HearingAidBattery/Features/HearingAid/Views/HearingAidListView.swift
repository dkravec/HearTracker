//
//  HearingAidListView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData

struct HearingAidListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HearingAid.createdAt, order: .reverse) private var hearingAids: [HearingAid]

    @StateObject private var viewModel = HearingAidListViewModel()

    private var activeAids: [HearingAid] {
        viewModel.activeAids(from: hearingAids)
    }

    private var retiredAids: [HearingAid] {
        viewModel.retiredAids(from: hearingAids)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if activeAids.isEmpty {
                            EmptyStateView(
                                title: "No Hearing Aids",
                                systemImage: "ear",
                                message: "Add a hearing aid to start tracking battery changes."
                            )
                        }

                        ForEach(activeAids) { aid in
                            HearingAidCardRow(
                                aid: aid,
                                onLogTapped: { viewModel.beginLog(for: aid) }
                            )
                        }

                        if viewModel.showsRetired, !retiredAids.isEmpty {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.clear)
            }
            .navigationTitle("Hearing Aids")
            .navigationDestination(for: HearingAid.self) { aid in
                HearingAidDetailView(aid: aid)
            }
            .navigationDestination(for: BatteryLogRoute.self) { route in
                BatteryLogDetailContainer(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Add") { AddHearingAidView().appBackground() }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if !retiredAids.isEmpty {
                        Button(viewModel.showsRetired ? "Hide Retired" : "Show Retired") {
                            viewModel.showsRetired.toggle()
                        }
                    }
                }
            }
        }
        .sheet(item: $viewModel.logTargetAid) { aid in
            BatteryLogSheet(
                note: $viewModel.logNote,
                onSave: { note in
                    viewModel.saveLog(for: aid, note: note, context: context)
                },
                onSaveWithoutNote: {
                    viewModel.saveLogWithoutNote(for: aid, context: context)
                },
                onCancel: {
                    viewModel.endLog()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .appBackground()
        }
    }
}

private struct HearingAidCardRow: View {
    let aid: HearingAid
    let onLogTapped: () -> Void

    var body: some View {
        NavigationLink(value: aid) {
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
