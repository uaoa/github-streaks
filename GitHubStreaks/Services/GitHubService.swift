import Foundation

// MARK: - GitHub Service Errors

enum GitHubServiceError: LocalizedError {
    case invalidUsername
    case networkError(Error)
    case parseError
    case rateLimited
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Invalid GitHub username"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError:
            return "Failed to parse GitHub data"
        case .rateLimited:
            return "GitHub API rate limit exceeded. Please try again later."
        case .userNotFound:
            return "GitHub user not found"
        }
    }
}

// MARK: - GitHub Service

actor GitHubService {
    static let shared = GitHubService()

    private init() {}

    // Fetch contributions by parsing the public contributions page
    // This approach doesn't require authentication and works for any public profile
    func fetchContributions(for username: String) async throws -> ContributionsData {
        guard !username.isEmpty else {
            throw GitHubServiceError.invalidUsername
        }

        let urlString = "https://github.com/users/\(username)/contributions"
        guard let url = URL(string: urlString) else {
            throw GitHubServiceError.invalidUsername
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubServiceError.parseError
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw GitHubServiceError.userNotFound
        case 429:
            throw GitHubServiceError.rateLimited
        default:
            throw GitHubServiceError.parseError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw GitHubServiceError.parseError
        }

        return try parseContributionsHTML(html, username: username)
    }

    // Parse the contributions HTML to extract contribution data
    private func parseContributionsHTML(_ html: String, username: String) throws -> ContributionsData {
        var days: [ContributionDay] = []
        var totalContributions = 0

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        // First, build a map of contribution-day-component IDs to dates
        // HTML format: data-date="2026-01-10" id="contribution-day-component-6-52"
        var idToDate: [String: Date] = [:]
        let cellPattern = #"data-date=\"(\d{4}-\d{2}-\d{2})\"[^>]*id=\"(contribution-day-component-\d+-\d+)\""#
        if let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            cellRegex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match = match,
                      let dateRange = Range(match.range(at: 1), in: html),
                      let idRange = Range(match.range(at: 2), in: html) else { return }

                let dateString = String(html[dateRange])
                let id = String(html[idRange])

                if let date = dateFormatter.date(from: dateString) {
                    idToDate[id] = date
                }
            }
        }

        // Parse tooltips to get actual contribution counts
        // Tool-tips have format: for="contribution-day-component-X-Y" ...>N contributions on ... or >No contributions on ...
        // Using dotMatchesLineSeparators to handle any whitespace in attributes
        let tooltipPattern = #"for=\"(contribution-day-component-\d+-\d+)\"[^>]*>(\d+)\s+contributions?\s+on"#
        let noContribPattern = #"for=\"(contribution-day-component-\d+-\d+)\"[^>]*>No\s+contributions?\s+on"#

        // First parse tooltips with contribution counts
        if let tooltipRegex = try? NSRegularExpression(pattern: tooltipPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            tooltipRegex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match = match,
                      let idRange = Range(match.range(at: 1), in: html),
                      let countRange = Range(match.range(at: 2), in: html) else { return }

                let id = String(html[idRange])
                guard let date = idToDate[id] else { return }

                let count = Int(String(html[countRange])) ?? 0
                days.append(ContributionDay(date: date, count: count))
                totalContributions += count
            }
        }

        // Then parse tooltips with no contributions (count = 0)
        var datesWithContributions = Set(days.map { $0.date })
        if let noContribRegex = try? NSRegularExpression(pattern: noContribPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            noContribRegex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match = match,
                      let idRange = Range(match.range(at: 1), in: html) else { return }

                let id = String(html[idRange])
                guard let date = idToDate[id], !datesWithContributions.contains(date) else { return }

                days.append(ContributionDay(date: date, count: 0))
                datesWithContributions.insert(date)
            }
        }

        // Fallback: if we didn't find tooltips, try parsing data-level
        if days.isEmpty {
            days = try parseAlternativeFormat(html, dateFormatter: dateFormatter)
            totalContributions = days.reduce(0) { $0 + $1.count }
        }

        // Try to extract actual total from page if available
        if let actualTotal = extractTotalContributions(from: html) {
            totalContributions = actualTotal
        }

        guard !days.isEmpty else {
            throw GitHubServiceError.parseError
        }

        return ContributionsData(
            username: username,
            totalContributions: totalContributions,
            days: days,
            fetchedAt: Date()
        )
    }

    // Alternative parsing for different HTML structures
    private func parseAlternativeFormat(_ html: String, dateFormatter: DateFormatter) throws -> [ContributionDay] {
        var days: [ContributionDay] = []

        // Try simpler pattern
        let pattern = #"data-date=\"(\d{4}-\d{2}-\d{2})\"[^>]*data-level=\"(\d)\""#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(html.startIndex..., in: html)

        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let dateRange = Range(match.range(at: 1), in: html),
                  let levelRange = Range(match.range(at: 2), in: html) else { return }

            let dateString = String(html[dateRange])
            let levelString = String(html[levelRange])

            guard let date = dateFormatter.date(from: dateString),
                  let level = Int(levelString) else { return }

            let count = estimateCount(from: level)
            days.append(ContributionDay(date: date, count: count))
        }

        return days
    }

    // Estimate contribution count from GitHub's level (0-4)
    private func estimateCount(from level: Int) -> Int {
        switch level {
        case 0: return 0
        case 1: return 2
        case 2: return 5
        case 3: return 8
        case 4: return 12
        default: return 0
        }
    }

    // Extract total contributions text like "1,136 contributions in the last year"
    private func extractTotalContributions(from html: String) -> Int? {
        let patterns = [
            #"([\d,]+)\s+contributions?\s+in\s+the\s+last\s+year"#,
            #"([\d,]+)\s+contributions?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let numberString = String(html[range]).replacingOccurrences(of: ",", with: "")
                return Int(numberString)
            }
        }

        return nil
    }
}

// MARK: - GraphQL API (requires token, optional enhancement)

extension GitHubService {
    // GraphQL query for contributions (requires GitHub token)
    private var contributionsQuery: String {
        """
        query($username: String!) {
            user(login: $username) {
                contributionsCollection {
                    contributionCalendar {
                        totalContributions
                        weeks {
                            contributionDays {
                                date
                                contributionCount
                                contributionLevel
                            }
                        }
                    }
                }
            }
        }
        """
    }

    // Fetch using GraphQL (for future enhancement with token support)
    func fetchContributionsGraphQL(for username: String, token: String) async throws -> ContributionsData {
        let url = URL(string: "https://api.github.com/graphql")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": contributionsQuery,
            "variables": ["username": username]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubServiceError.parseError
        }

        return try parseGraphQLResponse(data, username: username)
    }

    private func parseGraphQLResponse(_ data: Data, username: String) throws -> ContributionsData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any],
              let collection = user["contributionsCollection"] as? [String: Any],
              let calendar = collection["contributionCalendar"] as? [String: Any],
              let totalContributions = calendar["totalContributions"] as? Int,
              let weeks = calendar["weeks"] as? [[String: Any]] else {
            throw GitHubServiceError.parseError
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        var days: [ContributionDay] = []

        for week in weeks {
            guard let contributionDays = week["contributionDays"] as? [[String: Any]] else { continue }

            for day in contributionDays {
                guard let dateString = day["date"] as? String,
                      let count = day["contributionCount"] as? Int,
                      let date = dateFormatter.date(from: dateString) else { continue }

                days.append(ContributionDay(date: date, count: count))
            }
        }

        return ContributionsData(
            username: username,
            totalContributions: totalContributions,
            days: days,
            fetchedAt: Date()
        )
    }
}
