// Ganti seluruh kode di StartupManager.swift dengan ini

import Foundation
import ServiceManagement

struct StartupManager {
    static func toggleLaunchAtLogin(isEnabled: Bool) {
        do {
            // FIX: Menggunakan SMAppService() untuk kompatibilitas yang lebih luas,
            // alih-alih SMAppService.main yang hanya ada di macOS 13+.
            let service = SMAppService()
            
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("Failed to update launch at login setting: \(error.localizedDescription)")
        }
    }
}
