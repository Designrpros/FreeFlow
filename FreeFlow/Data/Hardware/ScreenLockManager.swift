//
//  ScreenLockManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit.pwr_mgt
#endif

final class ScreenLockManager {
    static let shared = ScreenLockManager()
    
    #if os(macOS)
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemAssertionID: IOPMAssertionID = 0
    #endif
    
    private init() {}
    
    /// Updates the system idle timer context based on the user's settings state
    func setScreenLockPrevention(enabled: Bool) {
        if enabled {
            enablePrevention()
        } else {
            disablePrevention()
        }
    }
    
    private func enablePrevention() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #elseif os(macOS)
        let reasonForActivity = "FreeFlow practice studio session active" as CFString
        
        // 1. Core Window Display Sleep Assertion
        if displayAssertionID == 0 {
            let success = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reasonForActivity,
                &displayAssertionID
            )
            if success != kIOReturnSuccess {
                print("Failed to disable display sleep on macOS.")
                displayAssertionID = 0
            }
        }
        
        // 2. FIXED: Core System/CPU Idle Sleep Assertion
        // Ensures backing audio file blocks keep streaming if the user locks their Mac screen via software or closes the laptop panel
        if systemAssertionID == 0 {
            let success = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reasonForActivity,
                &systemAssertionID
            )
            if success != kIOReturnSuccess {
                print("Failed to disable CPU idle system sleep on macOS.")
                systemAssertionID = 0
            }
        }
        #endif
    }
    
    private func disablePrevention() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #elseif os(macOS)
        // Clean release of display assertions
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        
        // Clean release of CPU background state sleep assertions
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
        #endif
    }
}
