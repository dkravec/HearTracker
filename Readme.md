# HearTracker Xcode
Created by Daniel Kravec, on Feb 21, 2026

# Hearing Aid Battery Tracker – Feature & Data Spec

## Goal

A simple iOS app to track battery changes for multiple hearing aids.

Primary use case:

* Tap “Log” when changing a battery
* See how long batteries last
* View history per hearing aid

Built with:

* SwiftUI
* SwiftData
* Fully offline

---

# Core Screens

## 1. Home Screen

Displays a list of hearing aids.

Each row shows:

* Hearing aid name
* Number of battery changes
* “Log” button (quick log action)

Actions:

* Tapping row → opens detail page
* “Log” button → instantly logs new battery change
* Toolbar button → Add new hearing aid

Retired hearing aids should be hidden by default.

---

## 2. Hearing Aid Detail Page

Displays:

* List of battery logs (newest first)
* Date + time
* Optional note
* “Current” label for active battery
* Duration (how long battery lasted) for past logs

Duration is calculated using linked logs.

---

## 3. Add Hearing Aid Page

Fields:

* Name (required)
* Retired toggle (optional)

---

# Data Models

## HearingAid

Fields:

* id: UUID
* createdAt: Date
* name: String
* retired: Bool
* logs: [BatteryLog] (relationship, cascade delete)

Derived:

* batteryChangeCount = logs.count

---

## BatteryLog

Fields:

* id: UUID
* timestamp: Date
* note: String?
* isCurrent: Bool
* nextLogId: UUID?  (points to newer log)
* hearingAid: HearingAid (relationship)

Purpose of `nextLogId`:

* Used to compute how long a battery lasted:
  duration = next.timestamp - this.timestamp

---

# Logging Logic (Critical Behavior)

When user presses “Log”:

1. Find current BatteryLog (where isCurrent == true)
2. Create new BatteryLog:

   * timestamp = now
   * isCurrent = true
3. If previous current exists:

   * set previous.isCurrent = false
   * set previous.nextLogId = newLog.id
4. Save context

Guarantees:

* Only one log per hearing aid is marked current
* Previous log links forward to the new one
* Durations can be computed reliably

---

# Duration Calculation

For a given BatteryLog:

* If nextLogId exists:

  * Find next log
  * duration = next.timestamp − current.timestamp
* Display as:

  * “3.8 days”
  * Or formatted days + hours

Current log does not show duration.

---

# Optional Enhancements (Not Required for MVP)

* Local notifications based on average battery life
* Simple battery life statistics (average, min, max)
* Apple Watch quick log button
* CSV export
* Pack tracking (how many batteries left)

---

# Architecture Notes

* Fully offline (with optional iCloud sync via SwiftData + CloudKit)
* No backend
* Use SwiftData relationships (no manual foreign keys)
* Use a service layer for quickLog logic
* Cascade delete logs when hearing aid is deleted
# iCloud Sync (SwiftData)

This app is configured to sync via CloudKit using the container:

* iCloud.net.novapro.HearingAidBattery

Requirements:

* Xcode capability: iCloud with CloudKit enabled
* Background Modes: Remote notifications enabled

