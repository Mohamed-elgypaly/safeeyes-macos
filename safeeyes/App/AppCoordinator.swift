import Foundation
import AppKit

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    let settingsManager: SettingsManager
    let idleMonitor: IdleMonitor
    let timeSource: SystemTimeSource
    let notificationService: NotificationService
    let overlay: OverlayPresenting
    let timerManager: TimerManager
    var menuBarController: MenuBarController?

    init() {
        let settings = SettingsManager()
        let idle = IdleMonitor()
        let time = SystemTimeSource()
        let notifications = NotificationService.shared
        let overlayPresenter = LoggingOverlay()

        self.settingsManager = settings
        self.idleMonitor = idle
        self.timeSource = time
        self.notificationService = notifications
        self.overlay = overlayPresenter

        self.timerManager = TimerManager(
            settings: settings,
            idle: idle,
            time: time,
            notifier: notifications,
            overlay: overlayPresenter
        )
    }

    func start() {
        Log.app.info("SafeEyes AppCoordinator started")

        // Install menu bar controller
        let menuBar = MenuBarController(timer: timerManager) { [weak self] in
            self?.openSettings()
        }
        menuBar.install()
        self.menuBarController = menuBar

        // Start timer loop
        timerManager.start()
    }

    func openSettings() {
        Log.app.info("Open settings requested")
        // Will be wired in Step 8 to SettingsWindowController
    }
}
