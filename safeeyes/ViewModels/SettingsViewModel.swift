// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation
import Combine
import SwiftUI
import AppKit

@MainActor
public final class SettingsViewModel: ObservableObject {
    public static let appLanguageKey = "appLanguage"
    public static let appleLanguagesKey = "AppleLanguages"

    private let settingsManager: SettingsStoring
    private let loginItemService: LoginItemControlling

    // MARK: - Breaks Tab
    @Published public var shortBreakIntervalMinutes: Int {
        didSet { pushChange() }
    }
    @Published public var shortBreakDurationSeconds: Int {
        didSet { pushChange() }
    }
    @Published public var longBreakEveryNShortBreaks: Int {
        didSet { pushChange() }
    }
    @Published public var longBreakDurationSeconds: Int {
        didSet { pushChange() }
    }
    @Published public var preBreakNoticeSeconds: Int {
        didSet { pushChange() }
    }

    // MARK: - Behavior Tab
    @Published public var strictMode: Bool {
        didSet { pushChange() }
    }
    @Published public var allowPostpone: Bool {
        didSet { pushChange() }
    }
    @Published public var postponeMinutes: Int {
        didSet { pushChange() }
    }
    @Published public var idlePauseThresholdSeconds: Int {
        didSet { pushChange() }
    }
    @Published public var playSounds: Bool {
        didSet { pushChange() }
    }
    @Published public var showExercises: Bool {
        didSet { pushChange() }
    }

    // MARK: - General Tab
    @Published public var launchAtLogin: Bool {
        didSet {
            guard !isPulling else { return }
            setLaunchAtLogin(launchAtLogin)
        }
    }
    @Published public private(set) var loginItemRequiresApproval: Bool = false

    // MARK: - Language Tab / Picker
    @Published public var appLanguage: String {
        didSet {
            guard !isPulling else { return }
            handleLanguageSelection(appLanguage)
        }
    }

    /// Alias for backwards compatibility
    public var selectedLanguage: String {
        get { appLanguage }
        set { appLanguage = newValue }
    }

    /// Tracks whether postpone should be disabled in the UI (strict mode overrides it)
    public var isPostponeDisabled: Bool {
        strictMode
    }

    private var isPulling = false

    public init(
        settingsManager: SettingsStoring,
        loginItemService: LoginItemControlling = LoginItemService.shared
    ) {
        self.settingsManager = settingsManager
        self.loginItemService = loginItemService
        let s = settingsManager.settings

        // Initialize all published properties from current settings
        self.shortBreakIntervalMinutes = s.shortBreakIntervalMinutes
        self.shortBreakDurationSeconds = s.shortBreakDurationSeconds
        self.longBreakEveryNShortBreaks = s.longBreakEveryNShortBreaks
        self.longBreakDurationSeconds = s.longBreakDurationSeconds
        self.preBreakNoticeSeconds = s.preBreakNoticeSeconds
        self.strictMode = s.strictMode
        self.allowPostpone = s.allowPostpone
        self.postponeMinutes = s.postponeMinutes
        self.idlePauseThresholdSeconds = s.idlePauseThresholdSeconds
        self.playSounds = s.playSounds
        self.showExercises = s.showExercises
        self.launchAtLogin = s.launchAtLogin
        self.appLanguage = Self.detectInitialLanguage()

        // Reconcile with system login item status on init
        reconcileLoginItem()
    }

    // MARK: - Language Management

    private static func detectInitialLanguage() -> String {
        if let saved = UserDefaults.standard.string(forKey: appLanguageKey), !saved.isEmpty {
            return saved == "ar" ? "ar" : "en"
        }
        if let languages = UserDefaults.standard.array(forKey: appleLanguagesKey) as? [String],
           let first = languages.first {
            return first.hasPrefix("ar") ? "ar" : "en"
        }
        if Locale.preferredLanguages.first?.hasPrefix("ar") == true {
            return "ar"
        }
        return "en"
    }

    private func handleLanguageSelection(_ lang: String) {
        UserDefaults.standard.set(lang, forKey: Self.appLanguageKey)
        UserDefaults.standard.set([lang], forKey: Self.appleLanguagesKey)
        UserDefaults.standard.synchronize()
    }

    private func loc(_ key: String) -> String {
        let lang = appLanguage
        if lang == "ar" {
            if let path = Bundle.main.path(forResource: "ar", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: key, table: nil)
            }
        } else if lang == "en" {
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: key, table: nil)
            }
        }
        return NSLocalizedString(key, comment: "")
    }

    public func promptRestart() {
        let alert = NSAlert()
        alert.messageText = loc("Restart Required")
        alert.informativeText = loc("Please restart SafeEyes for language changes to take full effect across the entire application (including the Menu Bar).")
        alert.alertStyle = .informational
        alert.addButton(withTitle: loc("Restart Now"))
        alert.addButton(withTitle: loc("Later"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            relaunchApplication()
        }
    }

    private func relaunchApplication() {
        // Spawn a detached helper that outlives us, then quit. (Calling openApplication on our own
        // bundle just re-activates the running instance, and a delayed fallback never fires once
        // terminate() has run.)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open -n \"$0\"", Bundle.main.bundlePath]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            Log.app.error("Failed to relaunch: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Login Item Management

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            isPulling = true
            launchAtLogin = loginItemService.isEnabled
            loginItemRequiresApproval = loginItemService.requiresApproval
            settingsManager.update { $0.launchAtLogin = self.launchAtLogin }
            isPulling = false
        } catch {
            Log.app.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            reconcileLoginItem()
        }
    }

    public func openLoginItemsSettings() {
        loginItemService.openLoginItemsSettings()
    }

    public func reconcileLoginItem() {
        let systemEnabled = loginItemService.isEnabled
        self.loginItemRequiresApproval = loginItemService.requiresApproval

        if launchAtLogin != systemEnabled {
            isPulling = true
            launchAtLogin = systemEnabled
            settingsManager.update { $0.launchAtLogin = systemEnabled }
            isPulling = false
        }
    }

    // MARK: - Push to SettingsManager

    private func pushChange() {
        guard !isPulling else { return }
        settingsManager.update { s in
            s.shortBreakIntervalMinutes = self.shortBreakIntervalMinutes
            s.shortBreakDurationSeconds = self.shortBreakDurationSeconds
            s.longBreakEveryNShortBreaks = self.longBreakEveryNShortBreaks
            s.longBreakDurationSeconds = self.longBreakDurationSeconds
            s.preBreakNoticeSeconds = self.preBreakNoticeSeconds
            s.strictMode = self.strictMode
            s.allowPostpone = self.allowPostpone
            s.postponeMinutes = self.postponeMinutes
            s.idlePauseThresholdSeconds = self.idlePauseThresholdSeconds
            s.playSounds = self.playSounds
            s.showExercises = self.showExercises
            s.launchAtLogin = self.launchAtLogin
        }

        // Pull back validated values (clamping may have adjusted them)
        pullFromSettings()
    }

    private func pullFromSettings() {
        isPulling = true
        defer { isPulling = false }

        let s = settingsManager.settings
        shortBreakIntervalMinutes = s.shortBreakIntervalMinutes
        shortBreakDurationSeconds = s.shortBreakDurationSeconds
        longBreakEveryNShortBreaks = s.longBreakEveryNShortBreaks
        longBreakDurationSeconds = s.longBreakDurationSeconds
        preBreakNoticeSeconds = s.preBreakNoticeSeconds
        strictMode = s.strictMode
        allowPostpone = s.allowPostpone
        postponeMinutes = s.postponeMinutes
        idlePauseThresholdSeconds = s.idlePauseThresholdSeconds
        playSounds = s.playSounds
        showExercises = s.showExercises
        launchAtLogin = s.launchAtLogin
        selectedLanguage = Self.detectInitialLanguage()
    }

    // MARK: - Actions

    public func resetToDefaults() {
        settingsManager.reset()
        pullFromSettings()
        reconcileLoginItem()

        UserDefaults.standard.removeObject(forKey: Self.appLanguageKey)
        UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        isPulling = true
        appLanguage = Self.detectInitialLanguage()
        isPulling = false
    }

    /// Formatted display of long break duration in minutes
    public var longBreakDurationMinutes: Int {
        get { longBreakDurationSeconds / 60 }
        set { longBreakDurationSeconds = newValue * 60 }
    }
}
