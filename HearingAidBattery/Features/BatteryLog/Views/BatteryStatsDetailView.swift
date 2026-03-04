//
//  BatteryStatsDetailView.swift
//  HearingAidBattery
//
//  Created by Codex on 2026-03-04.
//

import SwiftUI
import SwiftData
import Charts

struct BatteryStatsDetailView: View {
    @Environment(\.modelContext) private var context

    let aid: HearingAid

    @State private var stats: DetailedBatteryStats = .empty
    @State private var isLoading: Bool = true

    private let statsService = BatteryStatsService()
    private let durationFormatter = BatteryDurationFormatter()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if stats.totalBatteriesUsed == 0 {
                    EmptyStateView(
                        title: "No Battery Data",
                        systemImage: "chart.bar",
                        message: "Log some battery changes to see statistics."
                    )
                } else {
                    summarySection
                    if stats.durationHistory.isEmpty == false {
                        chartSection
                    }
                    trendSection
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("Battery Stats")
        .navigationBarTitleDisplayMode(.inline)
        .appBackground()
        .task {
            await loadStats()
        }
    }

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        SectionHeaderView(title: "Summary")
        CardRowContainer {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow(
                    title: "Total Batteries Used",
                    value: "\(stats.totalBatteriesUsed)",
                    icon: "bolt.batteryblock"
                )

                Divider()

                summaryRow(
                    title: "All-Time Average",
                    value: durationFormatter.optionalDaysText(from: stats.allTimeAvgDuration) ?? "—",
                    icon: "chart.bar"
                )

                Divider()

                summaryRow(
                    title: "Recent Average (last 10)",
                    value: durationFormatter.optionalDaysText(from: stats.recentAvgDuration) ?? "—",
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                )

                Divider()

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Best", systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(durationFormatter.optionalDaysText(from: stats.maxDuration) ?? "—")
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Worst", systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(durationFormatter.optionalDaysText(from: stats.minDuration) ?? "—")
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()
                }
            }
        }
    }

    private func summaryRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Chart Section

    @ViewBuilder
    private var chartSection: some View {
        SectionHeaderView(title: "Duration History")
        CardRowContainer {
            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    ForEach(stats.durationHistory) { point in
                        BarMark(
                            x: .value("Battery", point.index),
                            y: .value("Days", point.duration / 86_400.0)
                        )
                        .foregroundStyle(barColor(for: point))
                        .cornerRadius(4)
                    }

                    if let avg = stats.allTimeAvgDuration {
                        RuleMark(y: .value("Average", avg / 86_400.0))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Avg")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let days = value.as(Double.self) {
                                Text("\(Int(days))d")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)

                Text("Showing last \(stats.durationHistory.count) batteries • Orange line = average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barColor(for point: DurationDataPoint) -> Color {
        guard let avg = stats.allTimeAvgDuration else { return .blue }
        if point.duration >= avg * 1.1 {
            return .green
        } else if point.duration <= avg * 0.9 {
            return .red.opacity(0.8)
        }
        return .blue
    }

    // MARK: - Trend Section

    @ViewBuilder
    private var trendSection: some View {
        SectionHeaderView(title: "Trend")
        CardRowContainer {
            HStack(spacing: 12) {
                Image(systemName: trendIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(trendColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.trend.rawValue)
                        .font(.headline)
                    Text(trendDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var trendIcon: String {
        switch stats.trend {
        case .improving: return "arrow.up.right.circle.fill"
        case .declining: return "arrow.down.right.circle.fill"
        case .stable: return "equal.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var trendColor: Color {
        switch stats.trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        case .unknown: return .secondary
        }
    }

    private var trendDescription: String {
        switch stats.trend {
        case .improving: return "Recent batteries are lasting longer than older ones."
        case .declining: return "Recent batteries are lasting shorter than older ones."
        case .stable: return "Battery life has been consistent."
        case .unknown: return "Need at least 4 data points to determine trend."
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadStats() async {
        stats = statsService.detailedStats(
            for: aid.id,
            recentWindowSize: 10,
            historyLimit: 20,
            context: context
        )
        isLoading = false
    }
}
