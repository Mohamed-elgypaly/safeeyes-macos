// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import AppKit
import SwiftUI
import os

@MainActor
public final class OverlayWindowManager: NSObject, OverlayPresenting {
    private var timerManager: TimerManager?
    private let settingsManager: SettingsStoring

    private var windows: [BreakWindow] = []
    private var isBreakActive = false
    private var currentKind: BreakKind = .short
    private var isStrict = false
    private var previousFrontmostApp: NSRunningApplication?

    // Strict mode monitors & observers
    private var keyEventMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?
    private var emergencyExitTimer: Timer?
    private var screenRebuildTask: Task<Void, Never>?

    public init(settingsManager: SettingsStoring) {
        self.settingsManager = settingsManager
        super.init()
    }

    public func configure(timerManager: TimerManager) {
        self.timerManager = timerManager
    }


    public func show(kind: BreakKind, strict: Bool) {
        guard !isBreakActive else { return } // Idempotent

        isBreakActive = true
        currentKind = kind
        isStrict = strict
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        buildWindows()

        if strict {
            enableStrictMode()
        }

        startScreenChangeObservation()
    }

    public func hide() {
        guard isBreakActive else { return }

        isBreakActive = false
        stopScreenChangeObservation()

        if isStrict {
            disableStrictMode()
        }

        // Detach the windows being closed BEFORE animating. If show() runs again during the fade,
        // the completion handler must only tear down these old windows, never the new ones.
        let closing = windows
        windows = []
        let previous = previousFrontmostApp
        previousFrontmostApp = nil

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let fadeDuration: TimeInterval = reduceMotion ? 0.0 : 0.3

        if fadeDuration > 0 && !closing.isEmpty {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeDuration
                for window in closing {
                    window.animator().alphaValue = 0.0
                }
            }, completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.finishHide(closing, restoring: previous)
                }
            })
        } else {
            finishHide(closing, restoring: previous)
        }
    }

    // MARK: - Window Management

    private func buildWindows(animated: Bool = true) {
        guard let timerManager = timerManager else {
            Log.overlay.error("Cannot build windows: timerManager is nil")
            return
        }

        // Find screen under mouse or fallback to main screen
        let mouseLoc = NSEvent.mouseLocation
        let primaryScreen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let fadeDuration: TimeInterval = (reduceMotion || !animated) ? 0.0 : 0.3

        var newWindows: [BreakWindow] = []

        for screen in NSScreen.screens {
            let window = BreakWindow(screen: screen)
            let isPrimary = (screen == primaryScreen)

            let viewModel = BreakViewModel(
                timerManager: timerManager,
                settingsManager: settingsManager,
                kind: currentKind,
                strict: isStrict
            )

            let hostingView: NSView
            if isPrimary {
                hostingView = NSHostingView(rootView: BreakView(viewModel: viewModel))
            } else {
                hostingView = NSHostingView(rootView: SecondaryScreenView(viewModel: viewModel))
            }

            window.contentView = hostingView
            window.alphaValue = fadeDuration > 0 ? 0.0 : 1.0

            if isPrimary {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }

            newWindows.append(window)
        }

        self.windows = newWindows

        // Activate app
        activateApp()

        if fadeDuration > 0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeDuration
                for window in self.windows {
                    window.animator().alphaValue = 1.0
                }
            }
        }
    }

    private func finishHide(_ closing: [BreakWindow], restoring previous: NSRunningApplication?) {
        for window in closing {
            window.teardown()
        }

        // Don't steal focus back if a new break started while we were fading out
        guard !isBreakActive, let previous = previous else { return }
        if #available(macOS 14.0, *) {
            previous.activate()
        } else {
            previous.activate(options: .activateIgnoringOtherApps)
        }
    }

    private func rebuildWindowsForScreenChange() {
        guard isBreakActive else { return }
        Log.overlay.info("Rebuilding overlay windows for screen parameter change")

        for window in windows {
            window.teardown()
        }
        windows.removeAll()

        buildWindows(animated: false)
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Strict Mode

    private func enableStrictMode() {
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableHideApplication,
            .disableAppleMenu
        ]

        // Local monitor swallowing keyboard events, except emergency exit shortcut
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            guard let self = self else { return event }
            return self.handleStrictKeyEvent(event)
        }

        // Re-activation guard if focus is lost
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isBreakActive, self.isStrict else { return }
                self.activateApp()
                for window in self.windows {
                    window.orderFrontRegardless()
                }
            }
        }
    }

    private func disableStrictMode() {
        NSApp.presentationOptions = []

        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }

        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            resignActiveObserver = nil
        }

        cancelEmergencyTimer()
    }

    private func handleStrictKeyEvent(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isEmergencyModifiers = flags.contains([.option, .command, .shift])
        let isKeyE = (event.keyCode == 14) // QWERTY 'E'

        if isEmergencyModifiers && isKeyE {
            switch event.type {
            case .keyDown:
                if emergencyExitTimer == nil {
                    Log.overlay.warning("Emergency exit shortcut pressed, starting 5s hold timer")
                    emergencyExitTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            Log.overlay.warning("Emergency exit held for 5s: force-skipping break")
                            self?.emergencyExitTimer = nil
                            self?.timerManager?.send(.skipBreak(force: true))
                        }
                    }
                }
            case .keyUp:
                // Releasing E before 5s must cancel the hold
                cancelEmergencyTimer()
            default:
                break
            }
            return nil
        }

        // Any other key activity or modifier change cancels the hold
        cancelEmergencyTimer()

        // Swallow all input events in strict mode
        return nil
    }

    private func cancelEmergencyTimer() {
        guard emergencyExitTimer != nil else { return }
        emergencyExitTimer?.invalidate()
        emergencyExitTimer = nil
        Log.overlay.debug("Emergency exit shortcut released before 5s")
    }

    // MARK: - Screen Change Observation

    private func startScreenChangeObservation() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleScreenRebuild()
            }
        }
    }

    /// Hot-plugging a display posts several notifications in quick succession; coalesce them.
    private func scheduleScreenRebuild() {
        screenRebuildTask?.cancel()
        screenRebuildTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.rebuildWindowsForScreenChange()
        }
    }

    private func stopScreenChangeObservation() {
        screenRebuildTask?.cancel()
        screenRebuildTask = nil
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }
}
