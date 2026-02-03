import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    
    @Published var username: String {
        didSet {
            userDefaults.set(username, forKey: "username")
        }
    }
    
    @Published var menuBarMode: MenuBarDisplayMode {
        didSet {
            userDefaults.set(menuBarMode.rawValue, forKey: "menuBarMode")
        }
    }
    
    @Published var menuBarShowStreak: Bool {
        didSet {
            userDefaults.set(menuBarShowStreak, forKey: "menuBarShowStreak")
        }
    }
    
    @Published var menuBarDaysCount: Int {
        didSet {
            userDefaults.set(menuBarDaysCount, forKey: "menuBarDaysCount")
        }
    }
    
    @Published var menuBarDaysModeCount: Int {
        didSet {
            userDefaults.set(menuBarDaysModeCount, forKey: "menuBarDaysModeCount")
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: "launchAtLogin")
        }
    }
    
    private init() {
        self.username = userDefaults.string(forKey: "username") ?? ""
        self.menuBarMode = MenuBarDisplayMode(rawValue: userDefaults.string(forKey: "menuBarMode") ?? "Days") ?? .days
        self.menuBarShowStreak = userDefaults.object(forKey: "menuBarShowStreak") == nil ? true : userDefaults.bool(forKey: "menuBarShowStreak")
        self.menuBarDaysCount = userDefaults.integer(forKey: "menuBarDaysCount") == 0 ? 14 : userDefaults.integer(forKey: "menuBarDaysCount")
        self.menuBarDaysModeCount = userDefaults.integer(forKey: "menuBarDaysModeCount") == 0 ? 5 : userDefaults.integer(forKey: "menuBarDaysModeCount")
        self.launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
    }
}