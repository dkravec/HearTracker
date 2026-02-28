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
    private let statsService = BatteryStatsService()
    private let durationFormatter = BatteryDurationFormatter()
    private static let statsWindowSize: Int = 10

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
                        if activeAids.isEmpty == false {
                            SectionHeaderView(title: "Battery Stats")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(activeAids) { aid in
                                        let snapshot = statsService.statsSnapshot(
                                            for: aid.id,
                                            windowSize: Self.statsWindowSize,
                                            context: context
                                        )
                                        HomeBatteryStatsCard(
                                            aidName: aid.name,
                                            snapshot: snapshot,
                                            durationFormatter: durationFormatter
                                        )
                                    }
                                }
                                .padding(.horizontal, 1)
                                .padding(.vertical, 2)
                            }
                        }

                        if activeAids.isEmpty {
                            EmptyStateView(
                                title: "No Hearing Aids",
                                systemImage: "ear",
                                message: "Add a hearing aid to start tracking battery changes."
                            )
                        } else {
                            SectionHeaderView(title: "Hearing Aids")
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
                timestamp: $viewModel.logTimestamp,
                onSave: { timestamp, note in
                    viewModel.saveLog(for: aid, timestamp: timestamp, note: note, context: context)
                },
                onSaveWithoutNote: { timestamp in
                    viewModel.saveLogWithoutNote(for: aid, timestamp: timestamp, context: context)
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

private struct HomeBatteryStatsCard: View {
    let aidName: String
    let snapshot: BatteryStatsSnapshot
    let durationFormatter: BatteryDurationFormatter

    var body: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "battery.75")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(aidName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text("\(snapshot.sampleCount) samples")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }

                statRow(
                    title: "Current Age",
                    value: durationFormatter.optionalDaysText(from: snapshot.currentAge) ?? "Not enough data",
                    icon: "clock"
                )

                statRow(
                    title: "Average",
                    value: durationFormatter.optionalDaysText(from: snapshot.avgDuration) ?? "Not enough data",
                    icon: "chart.bar"
                )

                statRow(
                    title: "Predicted",
                    value: snapshot.predictedDeath.map { durationFormatter.relativeDateText(from: $0) } ?? "Not enough data",
                    icon: "calendar.badge.clock"
                )
            }
            .frame(width: 220, height: 200, alignment: .topLeading)
        }
    }

    private func statRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
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
