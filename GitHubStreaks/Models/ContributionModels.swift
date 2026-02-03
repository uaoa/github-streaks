import Foundation
import SwiftUI

// MARK: - Contribution Day

struct ContributionDay: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let count: Int
    let level: ContributionLevel

    init(date: Date, count: Int) {
        self.id = UUID()
        self.date = date
        self.count = count
        self.level = ContributionLevel.from(count: count)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        count = try container.decode(Int.self, forKey: .count)
        level = ContributionLevel.from(count: count)
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, count
    }
}

// MARK: - Contribution Level (matches GitHub's 5 levels)

enum ContributionLevel: Int, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case veryHigh = 4

    // Fixed thresholds (legacy, used for menu bar)
    static func from(count: Int) -> ContributionLevel {
        switch count {
        case 0: return .none
        case 1...2: return .low
        case 3...5: return .medium
        case 6...8: return .high
        default: return .veryHigh
        }
    }

    // Relative level based on max contributions (GitHub's algorithm)
    // Uses quartiles: 0 = none, 1-25% = low, 26-50% = medium, 51-75% = high, 76-100% = veryHigh
    static func relative(count: Int, max: Int) -> ContributionLevel {
        guard count > 0 else { return .none }
        guard max > 0 else { return .none }

        let percentage = Double(count) / Double(max)

        switch percentage {
        case 0:
            return .none
        case 0..<0.25:
            return .low
        case 0.25..<0.5:
            return .medium
        case 0.5..<0.75:
            return .high
        default:
            return .veryHigh
        }
    }

    var color: Color {
        switch self {
        case .none:
            return Color("ContributionNone")
        case .low:
            return Color("ContributionLow")
        case .medium:
            return Color("ContributionMedium")
        case .high:
            return Color("ContributionHigh")
        case .veryHigh:
            return Color("ContributionVeryHigh")
        }
    }

    // Updated GitHub colors (2024) - matches actual GitHub contribution graph exactly
    var fallbackColor: Color {
        switch self {
        case .none:
            return Color(light: Color(hex: "#ebedf0"), dark: Color(hex: "#161b22"))
        case .low:
            return Color(light: Color(hex: "#9be9a8"), dark: Color(hex: "#0e4429"))
        case .medium:
            return Color(light: Color(hex: "#40c463"), dark: Color(hex: "#006d32"))
        case .high:
            return Color(light: Color(hex: "#30a14e"), dark: Color(hex: "#26a641"))
        case .veryHigh:
            return Color(light: Color(hex: "#216e39"), dark: Color(hex: "#39d353"))
        }
    }
}

// MARK: - Contribution Week

struct ContributionWeek: Identifiable {
    let id = UUID()
    let days: [ContributionDay]
}

// MARK: - Contributions Data

struct ContributionsData: Codable {
    let username: String
    let totalContributions: Int
    let days: [ContributionDay]
    let fetchedAt: Date

    var weeks: [ContributionWeek] {
        // Group days into weeks (Sunday-Saturday)
        var weeks: [ContributionWeek] = []
        var currentWeekDays: [ContributionDay] = []

        for day in days.sorted(by: { $0.date < $1.date }) {
            let weekday = Calendar.current.component(.weekday, from: day.date)

            if weekday == 1 && !currentWeekDays.isEmpty {
                weeks.append(ContributionWeek(days: currentWeekDays))
                currentWeekDays = []
            }

            currentWeekDays.append(day)
        }

        if !currentWeekDays.isEmpty {
            weeks.append(ContributionWeek(days: currentWeekDays))
        }

        return weeks
    }

    // Calculate current streak
    var currentStreak: Int {
        let sortedDays = days.sorted { $0.date > $1.date }
        var streak = 0
        let calendar = Calendar.current
        
        // Use user's local calendar for today's date calculation
        // but compare using calendar date components rather than exact dates
        let now = Date()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        guard let today = calendar.date(from: todayComponents) else { return 0 }
        
        var expectedDate = today

        // Check if today has no contributions - start from yesterday
        if let todayContribution = sortedDays.first(where: { calendar.isDate($0.date, inSameDayAs: today) }),
           todayContribution.count == 0 {
            expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
        }

        for day in sortedDays {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: day.date)
            guard let dayDate = calendar.date(from: dayComponents) else { continue }
            
            if calendar.isDate(dayDate, inSameDayAs: expectedDate) {
                if day.count > 0 {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                } else {
                    break
                }
            } else if dayDate < expectedDate {
                break
            }
        }

        return streak
    }

    // Calculate longest streak
    var longestStreak: Int {
        let sortedDays = days.sorted { $0.date < $1.date }
        var longest = 0
        var current = 0
        let calendar = Calendar.current
        var previousDate: Date?

        for day in sortedDays {
            if day.count > 0 {
                if let prev = previousDate {
                    let prevComponents = calendar.dateComponents([.year, .month, .day], from: prev)
                    let dayComponents = calendar.dateComponents([.year, .month, .day], from: day.date)
                    
                    guard let prevDate = calendar.date(from: prevComponents),
                          let currentDate = calendar.date(from: dayComponents) else { continue }
                    
                    let daysDiff = calendar.dateComponents([.day], from: prevDate, to: currentDate).day ?? 0
                    if daysDiff == 1 {
                        current += 1
                    } else {
                        current = 1
                    }
                } else {
                    current = 1
                }
                longest = max(longest, current)
                previousDate = day.date
            } else {
                current = 0
                previousDate = nil
            }
        }

        return longest
    }

    var isCacheValid: Bool {
        // Cache valid for 30 minutes
        let cacheLifetime: TimeInterval = 30 * 60
        return Date().timeIntervalSince(fetchedAt) < cacheLifetime
    }
}

// MARK: - Menu Bar Display Mode

enum MenuBarDisplayMode: String, Codable, CaseIterable {
    case grid = "Grid"
    case days = "Days"
    case hidden = "Hidden"
}

// MARK: - App Settings

struct AppSettings: Codable {
    var username: String
    var menuBarMode: MenuBarDisplayMode
    var menuBarShowStreak: Bool
    var menuBarDaysCount: Int
    var menuBarDaysModeCount: Int
    var launchAtLogin: Bool

    static let `default` = AppSettings(
        username: "",
        menuBarMode: .days,
        menuBarShowStreak: true,
        menuBarDaysCount: 14,
        menuBarDaysModeCount: 5,
        launchAtLogin: false
    )

    init(username: String, menuBarMode: MenuBarDisplayMode, menuBarShowStreak: Bool = true, menuBarDaysCount: Int, menuBarDaysModeCount: Int = 5, launchAtLogin: Bool) {
        self.username = username
        self.menuBarMode = menuBarMode
        self.menuBarShowStreak = menuBarShowStreak
        self.menuBarDaysCount = menuBarDaysCount
        self.menuBarDaysModeCount = menuBarDaysModeCount
        self.launchAtLogin = launchAtLogin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        // Migration: handle old modes
        if let oldMode = try? container.decode(String.self, forKey: .menuBarMode) {
            switch oldMode {
            case "Streak Only", "Streak":
                menuBarMode = .hidden
                menuBarShowStreak = true
            case "Grid Only", "Grid":
                menuBarMode = .grid
                menuBarShowStreak = false
            case "Both":
                menuBarMode = .grid
                menuBarShowStreak = true
            case "Days":
                menuBarMode = .days
                menuBarShowStreak = try container.decodeIfPresent(Bool.self, forKey: .menuBarShowStreak) ?? false
            case "Hidden":
                menuBarMode = .hidden
                menuBarShowStreak = false
            default:
                menuBarMode = .days
                menuBarShowStreak = true
            }
        } else {
            menuBarMode = .days
            menuBarShowStreak = true
        }
        menuBarDaysCount = try container.decode(Int.self, forKey: .menuBarDaysCount)
        menuBarDaysModeCount = try container.decodeIfPresent(Int.self, forKey: .menuBarDaysModeCount) ?? 5
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            }
            return NSColor(light)
        })
    }
}
