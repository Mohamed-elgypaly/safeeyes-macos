// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation
@testable import SafeEyes

public final class FakeLoginItem: LoginItemControlling {
    public var isEnabled: Bool = false
    public var requiresApproval: Bool = false
    public var setEnabledError: Error?
    public var openSettingsCallCount = 0

    public init() {}

    public func setEnabled(_ enabled: Bool) throws {
        if let error = setEnabledError {
            throw error
        }
        isEnabled = enabled
    }

    public func openLoginItemsSettings() {
        openSettingsCallCount += 1
    }
}
