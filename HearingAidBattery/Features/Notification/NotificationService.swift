//
//  NotificationService.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import Foundation

final class NotificationService {
    func lowBatteryMessage(hearingAidName: String, estimatedDaysRemaining: Double?) -> String {
        guard let estimatedDaysRemaining else {
            return "Battery reminder for \(hearingAidName)."
        }

        return String(format: "%@ battery reminder: about %.1f days remaining.", hearingAidName, estimatedDaysRemaining)
    }
}
