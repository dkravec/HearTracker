//
//  BatteryPackView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI

struct BatteryPackListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Battery Packs")

                EmptyStateView(
                    title: "No Battery Packs",
                    systemImage: "shippingbox",
                    message: "Battery pack tracking will appear here."
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .appBackground()
    }
}

struct BatteryPackView: View {
    var body: some View {
        BatteryPackListView()
    }
}
