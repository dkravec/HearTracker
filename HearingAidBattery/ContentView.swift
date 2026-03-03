//
//  ContentView.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-21.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var activeSpaceSelection: ActiveSpaceSelectionService

    var body: some View {
        HearingAidListView()
            .id(activeSpaceSelection.activeSpaceId)
    }
}

#Preview {
    ContentView()
        .environmentObject(ActiveSpaceSelectionService())
        .modelContainer(
            for: [
                Space.self,
                HearingAid.self,
                BatteryLog.self,
                BatteryPack.self,
                IssueLog.self,
                NotificationModel.self],
            inMemory: true
        )
}
