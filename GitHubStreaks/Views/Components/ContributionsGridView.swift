import SwiftUI

struct ContributionsGridView: View {
    let weeks: [ContributionWeek]
    var onTap: (() -> Void)?

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 2) {
                // Day labels (Mon, Wed, Fri)
                dayLabelsView

                // Grid with month labels
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Month labels - inside ScrollView to sync
                            monthLabelsRow

                            // Grid
                            gridView
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("lastWeek", anchor: .trailing)
                    }
                }
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private var monthLabelsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, month in
                Text(month.name)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: CGFloat(month.weeks) * (cellSize + cellSpacing), alignment: .leading)
            }
        }
        .frame(height: 12)
    }

    private var dayLabelsView: some View {
        VStack(spacing: 0) {
            // Spacer for month labels row
            Color.clear
                .frame(height: 14)

            VStack(alignment: .trailing, spacing: cellSpacing) {
                ForEach(0..<7, id: \.self) { index in
                    Text(dayLabels[index])
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(height: cellSize)
                }
            }
        }
        .padding(.trailing, 2)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var gridView: some View {
        HStack(spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                VStack(spacing: cellSpacing) {
                    let paddedDays = paddedWeekDays(week.days)

                    ForEach(paddedDays) { dayWrapper in
                        if let day = dayWrapper.day {
                            ContributionDayCell(day: day, cellSize: cellSize)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
                .id(index == weeks.count - 1 ? "lastWeek" : nil)
            }
        }
    }

    private func paddedWeekDays(_ days: [ContributionDay]) -> [DayWrapper] {
        guard let firstDay = days.first else { return [] }

        let calendar = Calendar.current
        let firstWeekday = calendar.component(.weekday, from: firstDay.date)

        var result: [DayWrapper] = []

        for _ in 1..<firstWeekday {
            result.append(DayWrapper(id: UUID(), day: nil))
        }

        for day in days {
            result.append(DayWrapper(id: day.id, day: day))
        }

        while result.count < 7 {
            result.append(DayWrapper(id: UUID(), day: nil))
        }

        return result
    }

    private var monthLabels: [(name: String, weeks: Int)] {
        guard !weeks.isEmpty else { return [] }

        var labels: [(name: String, weeks: Int)] = []
        var currentMonth = -1
        var weekCount = 0
        var currentMonthDate: Date?

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        for week in weeks {
            guard let firstDay = week.days.first else { continue }

            let month = Calendar.current.component(.month, from: firstDay.date)

            if month != currentMonth {
                if currentMonth != -1 && weekCount > 0, let monthDate = currentMonthDate {
                    labels.append((name: formatter.string(from: monthDate), weeks: weekCount))
                }
                currentMonth = month
                currentMonthDate = firstDay.date
                weekCount = 1
            } else {
                weekCount += 1
            }
        }

        if currentMonth != -1 && weekCount > 0, let monthDate = currentMonthDate {
            labels.append((name: formatter.string(from: monthDate), weeks: weekCount))
        }

        return labels
    }
}

private struct DayWrapper: Identifiable {
    let id: UUID
    let day: ContributionDay?
}

// MARK: - Contribution Day Cell with Tooltip

struct ContributionDayCell: View {
    let day: ContributionDay
    let cellSize: CGFloat

    @State private var isHovered = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    private let hoverDelay: UInt64 = 200_000_000 // 400ms in nanoseconds

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(day.level.fallbackColor)
            .frame(width: cellSize, height: cellSize)
            .popover(isPresented: $showPopover, arrowEdge: .top) {
                tooltipContent
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: hoverDelay)
                        if !Task.isCancelled && isHovered {
                            showPopover = true
                        }
                    }
                } else {
                    hoverTask?.cancel()
                    hoverTask = nil
                    showPopover = false
                }
            }
    }

    private var tooltipContent: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        let contributions = day.count == 1 ? "contribution" : "contributions"

        return VStack(alignment: .leading, spacing: 4) {
            Text("\(day.count) \(contributions)")
                .font(.system(size: 12, weight: .semibold))
            Text(formatter.string(from: day.date))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}


// MARK: - Contribution Legend View

struct ContributionLegendView: View {
    private let cellSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            Spacer()

            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(ContributionLevel.allCases, id: \.rawValue) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level.fallbackColor)
                    .frame(width: cellSize, height: cellSize)
            }

            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

extension ContributionLevel: CaseIterable {
    static var allCases: [ContributionLevel] {
        [.none, .low, .medium, .high, .veryHigh]
    }
}
