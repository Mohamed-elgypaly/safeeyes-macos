import AppKit
import Combine

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private let timer: TimerManager
    private let onOpenSettings: () -> Void
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    // Retained menu item references for dynamic updates
    private let statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let takeBreakItem = NSMenuItem(title: "Take a Break Now", action: nil, keyEquivalent: "")
    private let pauseResumeItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
    private let skipBreakItem = NSMenuItem(title: "Skip Next Break", action: #selector(skipClicked), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
    private let aboutItem = NSMenuItem(title: "About SafeEyes", action: #selector(aboutClicked), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit SafeEyes", action: #selector(quitClicked), keyEquivalent: "q")

    public init(timer: TimerManager, onOpenSettings: @escaping () -> Void) {
        self.timer = timer
        self.onOpenSettings = onOpenSettings
        super.init()

        skipBreakItem.target = self
        settingsItem.target = self
        aboutItem.target = self
        quitItem.target = self

        // Observe timer state changes to refresh menu bar icon and text
        timer.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    public func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self

        // Status Line
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        // Take a Break Now Submenu
        let takeBreakSubmenu = NSMenu()
        let shortItem = NSMenuItem(title: "Short Break", action: #selector(takeShortBreak), keyEquivalent: "")
        shortItem.target = self
        takeBreakSubmenu.addItem(shortItem)

        let longItem = NSMenuItem(title: "Long Break", action: #selector(takeLongBreak), keyEquivalent: "")
        longItem.target = self
        takeBreakSubmenu.addItem(longItem)

        takeBreakItem.submenu = takeBreakSubmenu
        menu.addItem(takeBreakItem)

        // Pause / Resume Item
        menu.addItem(pauseResumeItem)

        // Skip Next Break
        menu.addItem(skipBreakItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item

        refresh()
    }

    public func refresh() {
        updateIcon()
        updateStatusText()
        updatePauseResumeMenu()
        updateSkipAndQuitItems()
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - UI Updates

    private func updateIcon() {
        guard let button = statusItem?.button else { return }

        let isPausedOrDisabled: Bool
        switch timer.state {
        case .paused, .disabled:
            isPausedOrDisabled = true
        default:
            isPausedOrDisabled = false
        }

        let symbolName = isPausedOrDisabled ? "eye.slash" : "eye"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SafeEyes")
        image?.isTemplate = true
        button.image = image
    }

    private func updateStatusText() {
        switch timer.state {
        case .working(let remaining, _):
            statusMenuItem.title = "Next break in \(formatTime(remaining))"
        case .preBreak(let kind, let remaining, _):
            let kindStr = (kind == .short) ? "Short" : "Long"
            statusMenuItem.title = "\(kindStr) break in \(formatTime(remaining))"
        case .onBreak(let kind, let remaining, _, _):
            let kindStr = (kind == .short) ? "Short" : "Long"
            statusMenuItem.title = "On a \(kindStr.lowercased()) break (\(formatTime(remaining)))"
        case .paused(let reason, _):
            switch reason {
            case .idle:
                statusMenuItem.title = "Paused (idle)"
            case .user(let until):
                if let until = until {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    statusMenuItem.title = "Paused until \(formatter.string(from: until))"
                } else {
                    statusMenuItem.title = "Paused"
                }
            case .system:
                statusMenuItem.title = "Paused (system)"
            }
        case .disabled:
            statusMenuItem.title = "SafeEyes Disabled"
        }
    }

    private func updatePauseResumeMenu() {
        switch timer.state {
        case .paused:
            pauseResumeItem.title = "Resume"
            pauseResumeItem.target = self
            pauseResumeItem.action = #selector(resumeClicked)
            pauseResumeItem.submenu = nil
        default:
            pauseResumeItem.title = "Pause"
            pauseResumeItem.target = nil
            pauseResumeItem.action = nil

            let pauseSubmenu = NSMenu()

            let m30 = NSMenuItem(title: "30 Minutes", action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            m30.tag = 30
            m30.target = self
            pauseSubmenu.addItem(m30)

            let m60 = NSMenuItem(title: "1 Hour", action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            m60.tag = 60
            m60.target = self
            pauseSubmenu.addItem(m60)

            let m120 = NSMenuItem(title: "2 Hours", action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            m120.tag = 120
            m120.target = self
            pauseSubmenu.addItem(m120)

            let mForever = NSMenuItem(title: "Until I Resume", action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            mForever.tag = 0
            mForever.target = self
            pauseSubmenu.addItem(mForever)

            pauseResumeItem.submenu = pauseSubmenu
        }
    }

    private func updateSkipAndQuitItems() {
        let isStrict = false
        let isStrictOnBreak = false

        // In strict mode while onBreak, quit is disabled
        quitItem.isEnabled = !isStrictOnBreak

        // Skip next break is hidden in strict mode
        skipBreakItem.isHidden = isStrict
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let minutes = s / 60
        let remainder = s % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    // MARK: - Actions

    @objc private func takeShortBreak() {
        timer.send(.takeBreakNow(.short))
    }

    @objc private func takeLongBreak() {
        timer.send(.takeBreakNow(.long))
    }

    @objc private func pauseDurationClicked(_ sender: NSMenuItem) {
        let minutes = sender.tag
        if minutes == 0 {
            timer.send(.userPause(duration: nil))
        } else {
            timer.send(.userPause(duration: TimeInterval(minutes * 60)))
        }
    }

    @objc private func resumeClicked() {
        timer.send(.resume)
    }

    @objc private func skipClicked() {
        timer.send(.skipBreak(force: false))
    }

    @objc private func settingsClicked() {
        onOpenSettings()
    }

    @objc private func aboutClicked() {
        NSApp.orderFrontStandardAboutPanel(
            options: [
                NSApplication.AboutPanelOptionKey.applicationName: "SafeEyes",
                NSApplication.AboutPanelOptionKey.version: "1.0.0"
            ]
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
