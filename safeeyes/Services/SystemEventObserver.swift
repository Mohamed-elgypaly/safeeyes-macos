// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation
import AppKit
import os

/// Observes macOS system events such as sleep/wake, display sleep, and screen lock/unlock,
/// and translates them into corresponding `SchedulerEvent`s dispatched to `TimerManager`.
@MainActor
public final class SystemEventObserver {
    private let timerManager: TimerManager
    private var sleepStartDate: Date?
    private var isScreenLocked = false
    private var wsObservers: [NSObjectProtocol] = []
    private var distObservers: [NSObjectProtocol] = []

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
        setupObservations()
    }

    deinit {
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsObservers.forEach { wsCenter.removeObserver($0) }

        let distCenter = DistributedNotificationCenter.default()
        distObservers.forEach { distCenter.removeObserver($0) }
    }

    private func setupObservations() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        let distCenter = DistributedNotificationCenter.default()

        // 1. System Sleep
        wsObservers.append(wsCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                Log.timer.info("System will sleep notification received")
                self.sleepStartDate = Date()
                self.timerManager.send(.systemWillSleep)
            }
        })

        // 2. System Wake
        wsObservers.append(wsCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let sleptFor = self.sleepStartDate.map { Date().timeIntervalSince($0) } ?? 0
                self.sleepStartDate = nil
                Log.timer.info("System did wake notification received (sleptFor: \(sleptFor, privacy: .public)s)")
                self.timerManager.send(.systemDidWake(sleptFor: sleptFor))
            }
        })

        // 3. Screens Did Sleep
        wsObservers.append(wsCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                Log.timer.info("Screens did sleep notification received")
                self?.timerManager.send(.screenLocked)
            }
        })

        // 3b. Screens Did Wake: display sleep without a lock never posts screenIsUnlocked,
        // so without this the timer would stay paused forever.
        wsObservers.append(wsCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isScreenLocked else { return }
                Log.timer.info("Screens did wake (not locked)")
                self.timerManager.send(.screenUnlocked)
            }
        })

        // 4. Screen Locked (macOS DistributedNotificationCenter)
        distObservers.append(distCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                Log.timer.info("Screen locked distributed notification received")
                self?.isScreenLocked = true
                self?.timerManager.send(.screenLocked)
            }
        })

        // 5. Screen Unlocked (macOS DistributedNotificationCenter)
        distObservers.append(distCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                Log.timer.info("Screen unlocked distributed notification received")
                self?.isScreenLocked = false
                self?.timerManager.send(.screenUnlocked)
            }
        })
    }
}
