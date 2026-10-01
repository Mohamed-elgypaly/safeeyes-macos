import Foundation

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    #if DEBUG
    private var debugIdleTimer: Timer?
    private let idleMonitor = IdleMonitor()
    #endif

    init() {}

    func start() {
        Log.app.info("SafeEyes AppCoordinator started")

        #if DEBUG
        debugIdleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let idle = self.idleMonitor.secondsSinceLastInput()
            Log.idle.debug("Current idle seconds: \(idle, privacy: .public)")
        }
        #endif
    }
}
