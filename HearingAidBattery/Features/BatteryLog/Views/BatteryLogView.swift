//
//  BatteryLogView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI

struct BatteryLogListView: View {
    @StateObject private var viewModel = BatteryLogListViewModel()
    let sortedLogs: [BatteryLog]
    let currentLogId: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Battery Logs")

                ForEach(Array(zip(sortedLogs, viewModel.rows)), id: \.0.id) { log, rowModel in
                    BatteryLogRow(log: log, rowModel: rowModel)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .task(id: refreshSignature) {
            viewModel.refresh(sortedLogs: sortedLogs, currentLogId: currentLogId)
        }
        .appBackground()
    }

    private var refreshSignature: String {
        sortedLogs
            .map { "\($0.id.uuidString)-\($0.timestamp.timeIntervalSince1970)-\($0.note ?? "")" }
            .joined(separator: "|")
    }
}

struct BatteryLogRow: View {
    let log: BatteryLog
    let rowModel: BatteryLogRowModel

    var body: some View {
        CardRowContainer {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(log.timestamp, style: .date)
                    Text(log.timestamp, style: .time)
                    Spacer()

                    if rowModel.isCurrent {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                }

                if let durationText = rowModel.durationText {
                    Text("Lasted: \(durationText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

typealias BatteryLogView = BatteryLogListView
