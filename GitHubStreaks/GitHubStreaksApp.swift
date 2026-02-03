import SwiftUI
import Combine

@main
struct GitHubStreaksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - we use menu bar only
        Settings {
            EmptyView()
        }
    }
}

class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var contextMenu: NSMenu!
    private var contributionsViewModel: ContributionsViewModel!
    private var eventMonitor: EventMonitor?
    private var rightClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        contributionsViewModel = ContributionsViewModel()
        setupMenuBar()
        setupContextMenu()
        setupPopover()
        setupEventMonitor()

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateMenuBarDisplay()
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe changes to update menu bar
        contributionsViewModel.$contributions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        contributionsViewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Bool) in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        contributionsViewModel.$menuBarMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: MenuBarDisplayMode) in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        contributionsViewModel.$menuBarShowStreak
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Bool) in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        contributionsViewModel.$menuBarDaysCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        contributionsViewModel.$menuBarDaysModeCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
    }

    private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        let mode = contributionsViewModel.menuBarMode
        let showStreak = contributionsViewModel.menuBarShowStreak

        if contributionsViewModel.isLoading && contributionsViewModel.contributions == nil {
            button.title = ""
            button.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Loading")
            return
        }

        // Build streak image if enabled
        let streakImage: NSImage? = showStreak ? createStreakImage() : nil

        // Set display based on mode
        switch mode {
        case .hidden:
            if showStreak {
                button.title = ""
                button.image = streakImage
            } else {
                button.title = ""
                button.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "GitHub")
            }

        case .grid:
            if showStreak, let streak = streakImage {
                button.title = ""
                button.image = combineImages(streak, createMiniGridImage(), spacing: 6)
            } else {
                button.title = ""
                button.image = createMiniGridImage()
            }

        case .days:
            if showStreak, let streak = streakImage {
                button.title = ""
                button.image = combineImages(streak, createDaysRowImage(), spacing: 6)
            } else {
                button.title = ""
                button.image = createDaysRowImage()
            }
        }
    }

    private func createStreakImage() -> NSImage {
        let streak = contributionsViewModel.currentStreak
        let hasStreak = streak > 0

        let iconName = "flame.fill"
        let iconColor = hasStreak ? NSColor.orange : NSColor.secondaryLabelColor

        guard let symbolImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Streak")?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium)) else {
            return NSImage()
        }

        let text = "\(streak)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: textAttributes)

        let iconSize = symbolImage.size
        let spacing: CGFloat = 2
        let totalWidth = iconSize.width + spacing + textSize.width
        let height = max(iconSize.height, textSize.height)

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()

        // Draw tinted icon
        let iconRect = NSRect(x: 0, y: (height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height)
        iconColor.set()
        symbolImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        // Draw text
        let textPoint = NSPoint(x: iconSize.width + spacing, y: (height - textSize.height) / 2)
        text.draw(at: textPoint, withAttributes: textAttributes)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func combineImages(_ left: NSImage, _ right: NSImage, spacing: CGFloat) -> NSImage {
        let totalWidth = left.size.width + spacing + right.size.width
        let height = max(left.size.height, right.size.height)

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()

        let leftRect = NSRect(x: 0, y: (height - left.size.height) / 2, width: left.size.width, height: left.size.height)
        left.draw(in: leftRect)

        let rightRect = NSRect(x: left.size.width + spacing, y: (height - right.size.height) / 2, width: right.size.width, height: right.size.height)
        right.draw(in: rightRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func createMiniGridImage() -> NSImage {
        let days = contributionsViewModel.menuBarDays
        let cellSize: CGFloat = 4
        let spacing: CGFloat = 1
        let rows = 7

        // Guard against empty days
        guard !days.isEmpty else {
            return NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "GitHub") ?? NSImage()
        }

        // Calculate columns needed
        let columns = min(max(1, (days.count + rows - 1) / rows), 8)
        let width = CGFloat(columns) * (cellSize + spacing)
        let height = CGFloat(rows) * (cellSize + spacing)

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        // Draw grid cells
        var dayIndex = 0
        for col in 0..<columns {
            for row in 0..<rows {
                let x = CGFloat(col) * (cellSize + spacing)
                let y = height - CGFloat(row + 1) * (cellSize + spacing)

                let rect = NSRect(x: x, y: y, width: cellSize, height: cellSize)

                if dayIndex < days.count {
                    let day = days[dayIndex]
                    let color = nsColorForLevel(day.level)
                    color.setFill()
                    dayIndex += 1
                } else {
                    NSColor.clear.setFill()
                }

                let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
                path.fill()
            }
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func createDaysRowImage() -> NSImage {
        let days = contributionsViewModel.menuBarDaysModeDays.reversed()
        let cellSize: CGFloat = 10
        let spacing: CGFloat = 2
        let count = days.count

        // Guard against empty days
        guard count > 0 else {
            return NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "GitHub") ?? NSImage()
        }

        let width = CGFloat(count) * cellSize + CGFloat(count - 1) * spacing
        let height = cellSize

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        for (index, day) in days.enumerated() {
            let x = CGFloat(index) * (cellSize + spacing)
            let rect = NSRect(x: x, y: 0, width: cellSize, height: cellSize)

            let color = nsColorForLevel(day.level)
            color.setFill()

            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func nsColorForLevel(_ level: ContributionLevel) -> NSColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        switch level {
        case .none:
            return isDark ? NSColor(hex: "#161b22") : NSColor(hex: "#ebedf0")
        case .low:
            return isDark ? NSColor(hex: "#0e4429") : NSColor(hex: "#9be9a8")
        case .medium:
            return isDark ? NSColor(hex: "#006d32") : NSColor(hex: "#40c463")
        case .high:
            return isDark ? NSColor(hex: "#26a641") : NSColor(hex: "#30a14e")
        case .veryHigh:
            return isDark ? NSColor(hex: "#39d353") : NSColor(hex: "#216e39")
        }
    }

    private func setupPopover() {
        let contentView = MainPopoverView(viewModel: contributionsViewModel)
        let hostingController = NSHostingController(rootView: contentView)

        panel = FocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        // Make the panel visually appear as a popover
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 10
            contentView.layer?.masksToBounds = true
        }
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }

            // Check if click is outside the panel
            let clickLocation = NSEvent.mouseLocation
            if !self.panel.frame.contains(clickLocation) {
                self.closePopover()
            }
        }
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        contextMenu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        contextMenu.addItem(settingsItem)

        contextMenu.addItem(NSMenuItem.separator())

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Launch at Login")
        contextMenu.addItem(launchAtLoginItem)

        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit")
        contextMenu.addItem(quitItem)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Update launch at login state
            if let launchItem = contextMenu.item(withTitle: "Launch at Login") {
                launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
            }
            
            // Update refresh item state
            if let refreshItem = contextMenu.item(withTitle: "Refresh") {
                refreshItem.title = contributionsViewModel.isLoading ? "Refreshing..." : "Refresh"
                refreshItem.isEnabled = !contributionsViewModel.isLoading
            }
            
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    @objc private func togglePopover() {
        if panel.isVisible {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc private func refreshData() {
        if !contributionsViewModel.isLoading {
            contributionsViewModel.refresh()
        }
    }

    @objc private func openSettings() {
        contributionsViewModel.showSettings = true
        showPopover()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.shared.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        // Position panel below the status item
        let buttonRect = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
        let panelSize = panel.frame.size
        let x = buttonRect.midX - panelSize.width / 2
        let y = buttonRect.minY - panelSize.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        eventMonitor?.start()
    }

    private func closePopover() {
        panel.orderOut(nil)
        eventMonitor?.stop()
    }
}

// MARK: - NSColor hex extension

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}
