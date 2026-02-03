import Foundation
import Combine
import SwiftUI

@MainActor
class ContributionsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var contributions: ContributionsData?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSettings = false

    // MARK: - Settings

    @Published var username: String {
        didSet {
            settingsManager.username = username
            if !username.isEmpty {
                Task { await fetchContributions(forceRefresh: true) }
            }
        }
    }

    @Published var menuBarMode: MenuBarDisplayMode {
        didSet {
            settingsManager.menuBarMode = menuBarMode
        }
    }

    @Published var menuBarShowStreak: Bool {
        didSet {
            settingsManager.menuBarShowStreak = menuBarShowStreak
        }
    }

    @Published var menuBarDaysCount: Int {
        didSet {
            settingsManager.menuBarDaysCount = menuBarDaysCount
        }
    }

    @Published var menuBarDaysModeCount: Int {
        didSet {
            settingsManager.menuBarDaysModeCount = menuBarDaysModeCount
        }
    }

    // MARK: - Computed Properties

    var totalContributions: Int {
        contributions?.totalContributions ?? 0
    }

    var currentStreak: Int {
        contributions?.currentStreak ?? 0
    }

    var longestStreak: Int {
        contributions?.longestStreak ?? 0
    }

    // All weeks for the full year display in popover
    var allWeeks: [ContributionWeek] {
        guard let contributions = contributions else { return [] }
        return contributions.weeks
    }

    // Days for menu bar mini grid (based on menuBarDaysCount)
    var menuBarDays: [ContributionDay] {
        guard let contributions = contributions else { return [] }
        let sortedDays = contributions.days.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -menuBarDaysCount, to: Date()) ?? Date()
        return sortedDays.filter { $0.date >= cutoffDate }
    }

    // Days for menu bar Days mode (large squares in a row)
    var menuBarDaysModeDays: [ContributionDay] {
        guard let contributions = contributions else { return [] }
        let sortedDays = contributions.days.sorted { $0.date > $1.date }
        return Array(sortedDays.prefix(menuBarDaysModeCount))
    }

    var contributionsText: String {
        let count = totalContributions
        return "\(count.formatted()) contributions in the last year"
    }

    // MARK: - Private Properties

    private let settingsManager = SettingsManager.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.username = settingsManager.username
        self.menuBarMode = settingsManager.menuBarMode
        self.menuBarShowStreak = settingsManager.menuBarShowStreak
        self.menuBarDaysCount = settingsManager.menuBarDaysCount
        self.menuBarDaysModeCount = settingsManager.menuBarDaysModeCount

        setupAutoRefresh()

        // Initial fetch if username is set
        if !username.isEmpty {
            Task { await fetchContributions() }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    func fetchContributions(forceRefresh: Bool = false) async {
        guard !username.isEmpty else {
            error = "Please set a GitHub username"
            return
        }

        print("🔄 Starting contribution fetch for \(username), forceRefresh: \(forceRefresh)")
        isLoading = true
        error = nil

        // Check cache first
        if !forceRefresh {
            if let cached = await CacheManager.shared.getCachedContributions(for: username) {
                print("📦 Using cached data for \(username)")
                contributions = cached
                isLoading = false
                return
            }
        }

        do {
            print("🌐 Fetching fresh data from GitHub for \(username)")
            let data = try await GitHubService.shared.fetchContributions(for: username)
            await CacheManager.shared.cacheContributions(data)
            contributions = data
            print("✅ Successfully fetched \(data.totalContributions) contributions, current streak: \(data.currentStreak)")
        } catch let fetchError as GitHubServiceError {
            print("❌ GitHub service error: \(fetchError.errorDescription ?? "Unknown error")")
            error = fetchError.errorDescription
            // Keep showing cached data on error
            if contributions == nil {
                contributions = await CacheManager.shared.getCachedContributions(for: username)
                if contributions != nil {
                    print("📦 Falling back to cached data after error")
                }
            }
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        isLoading = false
        print("🏁 Contribution fetch completed for \(username)")
    }

    func refresh() {
        Task { await fetchContributions(forceRefresh: true) }
    }

    func openGitHubProfile() {
        guard !username.isEmpty else { return }
        if let url = URL(string: "https://github.com/\(username)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openGitHubDate(_ date: Date) {
        guard !username.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        if let url = URL(string: "https://github.com/\(username)?tab=overview&from=\(dateString)&to=\(dateString)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    private func setupAutoRefresh() {
        // Refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchContributions(forceRefresh: true)
            }
        }
    }
}
