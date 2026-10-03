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
    private let takeBreakItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let shortBreakItem = NSMenuItem(title: "", action: #selector(takeShortBreak), keyEquivalent: "")
    private let longBreakItem = NSMenuItem(title: "", action: #selector(takeLongBreak), keyEquivalent: "")
    private let pauseResumeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let skipBreakItem = NSMenuItem(title: "", action: #selector(skipClicked), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: #selector(settingsClicked), keyEquivalent: ",")
    private let aboutItem = NSMenuItem(title: "", action: #selector(aboutClicked), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "", action: #selector(quitClicked), keyEquivalent: "q")

    public init(timer: TimerManager, onOpenSettings: @escaping () -> Void) {
        self.timer = timer
        self.onOpenSettings = onOpenSettings
        super.init()

        shortBreakItem.target = self
        longBreakItem.target = self
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
        takeBreakSubmenu.addItem(shortBreakItem)
        takeBreakSubmenu.addItem(longBreakItem)
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
        updateStaticMenuTitles()
        updateStatusText()
        updatePauseResumeMenu()
        updateSkipAndQuitItems()
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - Localization Helper

    private func loc(_ key: String) -> String {
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = langs.first {
            if first.hasPrefix("ar"),
               let path = Bundle.main.path(forResource: "ar", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: key, table: nil)
            } else if first.hasPrefix("en"),
                      let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                      let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: key, table: nil)
            }
        }
        return NSLocalizedString(key, comment: "")
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

    private func updateStaticMenuTitles() {
        takeBreakItem.title = loc("Take a Break Now")
        shortBreakItem.title = loc("Short Break")
        longBreakItem.title = loc("Long Break")
        skipBreakItem.title = loc("Skip Next Break")
        settingsItem.title = loc("Settings…")
        aboutItem.title = loc("About SafeEyes")
        quitItem.title = loc("Quit SafeEyes")
    }

    private func updateStatusText() {
        switch timer.state {
        case .working(let remaining, _):
            let format = loc("Next break in %@")
            statusMenuItem.title = String(format: format, formatTime(remaining))

        case .preBreak(let kind, let remaining, _):
            let format = (kind == .short)
                ? loc("Short break in %@")
                : loc("Long break in %@")
            statusMenuItem.title = String(format: format, formatTime(remaining))

        case .onBreak(let kind, let remaining, _, _):
            let format = (kind == .short)
                ? loc("On a short break (%@)")
                : loc("On a long break (%@)")
            statusMenuItem.title = String(format: format, formatTime(remaining))

        case .paused(let reason, _):
            switch reason {
            case .idle:
                statusMenuItem.title = loc("Paused (idle)")
            case .user(let until):
                if let until = until {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    let format = loc("Paused until %@")
                    statusMenuItem.title = String(format: format, formatter.string(from: until))
                } else {
                    statusMenuItem.title = loc("Paused")
                }
            case .system:
                statusMenuItem.title = loc("Paused (system)")
            }

        case .disabled:
            statusMenuItem.title = loc("SafeEyes Disabled")
        }
    }

    private func updatePauseResumeMenu() {
        switch timer.state {
        case .paused:
            pauseResumeItem.title = loc("Resume")
            pauseResumeItem.target = self
            pauseResumeItem.action = #selector(resumeClicked)
            pauseResumeItem.submenu = nil
        default:
            pauseResumeItem.title = loc("Pause")
            pauseResumeItem.target = nil
            pauseResumeItem.action = nil

            let pauseSubmenu = NSMenu()

            let m30 = NSMenuItem(title: loc("30 Minutes"), action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            m30.tag = 30
            m30.target = self
            pauseSubmenu.addItem(m30)

            let m60 = NSMenuItem(title: loc("1 Hour"), action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            m60.tag = 60
            m60.target = self
            pauseSubmenu.addItem(m60)

            let m120 = NSMenuItem(title: loc("2 Hours"), action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
            m120.tag = 120
            m120.target = self
            pauseSubmenu.addItem(m120)

            let mForever = NSMenuItem(title: loc("Until I Resume"), action: #selector(pauseDurationClicked(_:)), keyEquivalent: "")
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
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let remainder = s % 60

        if hours > 0 {
            return String(format: "%dh %dm %02ds", hours, minutes, remainder)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, remainder)
        } else {
            return "\(remainder)s"
        }
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
