import Foundation
import Combine
import SwiftUI

@MainActor
public final class SettingsViewModel: ObservableObject {
    private let settingsManager: SettingsManager

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
        didSet { pushChange() }
    }

    /// Tracks whether postpone should be disabled in the UI (strict mode overrides it)
    public var isPostponeDisabled: Bool {
        strictMode
    }

    private var isPulling = false

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
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
    }

    // MARK: - Actions

    public func resetToDefaults() {
        settingsManager.reset()
        pullFromSettings()
    }

    /// Formatted display of long break duration in minutes
    public var longBreakDurationMinutes: Int {
        get { longBreakDurationSeconds / 60 }
        set { longBreakDurationSeconds = newValue * 60 }
    }
}
