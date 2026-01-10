import Foundation

// MARK: - Cache Manager

actor CacheManager {
    static let shared = CacheManager()

    private let userDefaults = UserDefaults.standard
    private let contributionsKey = "cached_contributions"
    private let settingsKey = "app_settings"

    private init() {}

    // MARK: - Contributions Cache

    func getCachedContributions(for username: String) -> ContributionsData? {
        guard let data = userDefaults.data(forKey: "\(contributionsKey)_\(username)") else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let contributions = try decoder.decode(ContributionsData.self, from: data)

            // Check if cache is still valid
            if contributions.isCacheValid {
                return contributions
            }
        } catch {
            print("Failed to decode cached contributions: \(error)")
        }

        return nil
    }

    func cacheContributions(_ contributions: ContributionsData) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contributions)
            userDefaults.set(data, forKey: "\(contributionsKey)_\(contributions.username)")
        } catch {
            print("Failed to cache contributions: \(error)")
        }
    }

    func clearContributionsCache(for username: String) {
        userDefaults.removeObject(forKey: "\(contributionsKey)_\(username)")
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return .default
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            return .default
        }
    }

    func saveSettings(_ settings: AppSettings) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
}

// MARK: - Settings Manager (Observable)

import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            Task {
                await CacheManager.shared.saveSettings(settings)
            }
        }
    }

    private init() {
        // Load settings synchronously for initialization
        if let data = UserDefaults.standard.data(forKey: "app_settings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = settings
        } else {
            self.settings = .default
        }
    }

    var username: String {
        get { settings.username }
        set { settings.username = newValue }
    }

    var menuBarMode: MenuBarDisplayMode {
        get { settings.menuBarMode }
        set { settings.menuBarMode = newValue }
    }

    var menuBarShowStreak: Bool {
        get { settings.menuBarShowStreak }
        set { settings.menuBarShowStreak = newValue }
    }

    var menuBarDaysCount: Int {
        get { settings.menuBarDaysCount }
        set { settings.menuBarDaysCount = newValue }
    }

    var menuBarDaysModeCount: Int {
        get { settings.menuBarDaysModeCount }
        set { settings.menuBarDaysModeCount = newValue }
    }

    var launchAtLogin: Bool {
        get { settings.launchAtLogin }
        set { settings.launchAtLogin = newValue }
    }
}
