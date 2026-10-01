import Foundation

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    init() {}

    func start() {
        Log.app.info("SafeEyes AppCoordinator started")
    }
}
