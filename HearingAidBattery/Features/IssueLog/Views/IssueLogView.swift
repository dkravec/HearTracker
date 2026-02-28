//
//  IssueLogView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI

struct IssueLogListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Issue Logs")

                EmptyStateView(
                    title: "No Issues Logged",
                    systemImage: "exclamationmark.bubble",
                    message: "Issue tracking entries will appear here."
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .appBackground()
    }
}

struct IssueLogView: View {
    var body: some View {
        IssueLogListView()
    }
}
