# AGENTS

## Project Summary
Hearing Aid Battery Tracker is a SwiftUI + SwiftData iOS app that logs hearing aid battery changes and shows durations between logs. The app is fully offline.

## Key Files
- Models: `HearingAidBattery/HearingAidBattery/Models/HearingAid.swift`, `HearingAidBattery/HearingAidBattery/Models/BatteryLog.swift`
- Service: `HearingAidBattery/HearingAidBattery/Services/BatteryLogService.swift`
- Views: `HearingAidBattery/HearingAidBattery/Views/HearingAidListView.swift`, `HearingAidBattery/HearingAidBattery/Views/HearingAidDetailView.swift`, `HearingAidBattery/HearingAidBattery/Views/AddHearingAidView.swift`
- Entry: `HearingAidBattery/HearingAidBattery/ContentView.swift`, `HearingAidBattery/HearingAidBattery/HearingAidBatteryApp.swift`

## Core Behavior (Must Preserve)
- Quick log flow:
  1) Find current log (`isCurrent == true`).
  2) Create new log with `timestamp = now`, `isCurrent = true`.
  3) If previous current exists, set `isCurrent = false` and `nextLogId = newLog.id`.
  4) Save context.
- Exactly one current log per hearing aid.
- Durations are computed via `nextLogId` and do not display for the current log.

## Coding Conventions
- SwiftUI with SwiftData; avoid Combine; prefer async/await.
- Use `@State private var` for view state; `let` for constants.
- 4-space indentation.
- Add brief comments only for non-obvious logic.
- Avoid force unwrapping.

## Tests
- Unit tests: Testing framework.
- UI tests: XCUIAutomation.

## Tooling Guidance
- Prefer Xcode tools (XcodeGlob/XcodeRead/XcodeUpdate/XcodeWrite).
- Use `XcodeRefreshCodeIssuesInFile` for quick validation before full builds.
