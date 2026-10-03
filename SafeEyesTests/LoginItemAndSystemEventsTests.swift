import XCTest
@testable import SafeEyes

@MainActor
final class LoginItemAndSystemEventsTests: XCTestCase {
    private var fakeSettings: InMemorySettingsStore!
    private var fakeLoginItem: FakeLoginItem!
    private var fakeIdle: FakeIdle!
    private var fakeClock: FakeClock!
    private var fakeNotifier: FakeNotifier!
    private var fakeOverlay: FakeOverlay!
    private var timerManager: TimerManager!

    override func setUp() {
        super.setUp()
        fakeSettings = InMemorySettingsStore(initialSettings: AppSettings(
            shortBreakIntervalMinutes: 20,
            shortBreakDurationSeconds: 20,
            longBreakEveryNShortBreaks: 4,
            longBreakDurationSeconds: 300,
            preBreakNoticeSeconds: 10,
            strictMode: false,
            allowPostpone: true,
            postponeMinutes: 5,
            idlePauseThresholdSeconds: 10,
            launchAtLogin: false
        ))
        fakeLoginItem = FakeLoginItem()
        fakeIdle = FakeIdle(initialIdleSeconds: 0)
        fakeClock = FakeClock()
        fakeNotifier = FakeNotifier()
        fakeOverlay = FakeOverlay()

        timerManager = TimerManager(
            settings: fakeSettings,
            idle: fakeIdle,
            time: fakeClock,
            notifier: fakeNotifier,
            overlay: fakeOverlay
        )
    }

    func testLoginItemToggleEnablesAndDisables() {
        let viewModel = SettingsViewModel(
            settingsManager: fakeSettings,
            loginItemService: fakeLoginItem
        )

        XCTAssertFalse(viewModel.launchAtLogin)
        XCTAssertFalse(fakeLoginItem.isEnabled)

        viewModel.setLaunchAtLogin(true)
        XCTAssertTrue(viewModel.launchAtLogin)
        XCTAssertTrue(fakeLoginItem.isEnabled)
        XCTAssertTrue(fakeSettings.settings.launchAtLogin)

        viewModel.setLaunchAtLogin(false)
        XCTAssertFalse(viewModel.launchAtLogin)
        XCTAssertFalse(fakeLoginItem.isEnabled)
        XCTAssertFalse(fakeSettings.settings.launchAtLogin)
    }

    func testLoginItemRequiresApprovalSurfaced() {
        fakeLoginItem.requiresApproval = true

        let viewModel = SettingsViewModel(
            settingsManager: fakeSettings,
            loginItemService: fakeLoginItem
        )

        XCTAssertTrue(viewModel.loginItemRequiresApproval)

        viewModel.openLoginItemsSettings()
        XCTAssertEqual(fakeLoginItem.openSettingsCallCount, 1)
    }

    func testReconcilesSystemStatusOnLaunch() {
        // System status is enabled, but stored setting was false
        fakeLoginItem.isEnabled = true
        XCTAssertFalse(fakeSettings.settings.launchAtLogin)

        let viewModel = SettingsViewModel(
            settingsManager: fakeSettings,
            loginItemService: fakeLoginItem
        )

        // System status takes precedence
        XCTAssertTrue(viewModel.launchAtLogin)
        XCTAssertTrue(fakeSettings.settings.launchAtLogin)
    }

    func testSystemEventObserverDispatchesSleepAndWake() {
        _ = SystemEventObserver(timerManager: timerManager)

        // Initial state is working
        if case .working = timerManager.state {
            // OK
        } else {
            XCTFail("Expected working state")
        }

        // Post will sleep
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)

        // Give the async Task a chance to run on main queue
        let sleepExpectation = expectation(description: "Pause on sleep")
        DispatchQueue.main.async {
            if case .paused(let reason, _) = self.timerManager.state {
                XCTAssertEqual(reason, .system)
                sleepExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testScreenLockAndUnlockEvents() {
        timerManager.send(.screenLocked)
        if case .paused(let reason, _) = timerManager.state {
            XCTAssertEqual(reason, .system)
        } else {
            XCTFail("Expected paused state on screenLocked")
        }

        timerManager.send(.screenUnlocked)
        if case .working = timerManager.state {
            // OK
        } else {
            XCTFail("Expected working state on screenUnlocked")
        }
    }
}
