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

# Implemented Features

## Core
* **Battery Logging** – Log when batteries are opened/changed
* **Multiple Hearing Aids** – Track left, right, backups independently
* **Usage Prediction** – Average battery life and predicted death date
* **iCloud Sync** – Automatic sync via CloudKit

## Inventory & Cost
* **Battery Packs** – Track inventory by type, quantity, purchase date
* **Cost Tracking** – Cost per day calculation with multi-currency support
* **Low Stock Alerts** – Notifications when packs run low

## Issues & History
* **Issue Logging** – Record problems (dead on arrival, unusual drain, feedback)
* **Notes Import** – Import existing data from Notes/spreadsheets

## Notifications
* **Expected Death Warning** – Alert before battery dies (configurable hours/minutes)
* **Morning Heads-Up** – Daily reminder at chosen time
* **Per-Aid Toggles** – Enable/disable notifications per hearing aid

## Organization
* **Spaces** – Separate profiles for caregivers managing multiple people
* **Backup/Export** – Import/export data

---

# Stats Enhancements (Proposed)

## Current Stats (Home Page Cards)
* Current age / Predicted death
* Average duration (rolling 10-sample window)
* Cost per day
* Sample count

## Proposed: Dedicated Stats View
Tappable stats card → navigates to detailed stats screen:

### Summary Section
* All-time average vs. recent (last 10) average
* Best/worst battery duration
* Total batteries used
* Total cost spent

### History Chart (Mini Bar Chart)
* Last 10-20 battery durations as bars
* Horizontal line showing average
* Tap bar → shows that log's details

### Trends
* Duration trend (improving/declining/stable)
* Seasonal patterns (if enough data)
* Per-aid comparison (side by side)

### Cost Analysis
* Cost per day over time
* Cost per hearing aid
* Monthly/yearly projections

---

# Future Enhancements

* Apple Watch quick log button
* CSV export
* Widgets (battery status, predicted death)
* Siri shortcuts ("Log battery for left aid")

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

