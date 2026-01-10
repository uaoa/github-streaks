import Foundation
import ServiceManagement

// Manages Launch at Login functionality using SMAppService (macOS 13+)
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false

    private init() {
        updateStatus()
    }

    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    func enable() {
        do {
            try SMAppService.mainApp.register()
            updateStatus()
        } catch {
            print("Failed to enable launch at login: \(error)")
        }
    }

    func disable() {
        do {
            try SMAppService.mainApp.unregister()
            updateStatus()
        } catch {
            print("Failed to disable launch at login: \(error)")
        }
    }

    private func updateStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
