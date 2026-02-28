//
//  ContentView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HearingAidListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                HearingAid.self,
                BatteryLog.self,
                BatteryPack.self,
                IssueLog.self,
                NotificationModel.self],
            inMemory: true
        )
}
