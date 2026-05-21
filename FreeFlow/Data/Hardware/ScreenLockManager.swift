//
//  ScreenLockManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
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
    private var assertionID: IOPMAssertionID = 0
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
        guard assertionID == 0 else { return }
        let reasonForActivity = "FreeFlow practice session active" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &assertionID
        )
        if success != kIOReturnSuccess {
            print("Failed to disable display sleep on macOS.")
            assertionID = 0
        }
        #endif
    }
    
    private func disablePrevention() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #elseif os(macOS)
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        #endif
    }
}
