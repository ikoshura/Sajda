// Ganti seluruh kode di StartupManager.swift dengan ini

import Foundation
import ServiceManagement

struct StartupManager {
    static var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggleLaunchAtLogin(isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login setting: \(error.localizedDescription)")
        }
    }
}
