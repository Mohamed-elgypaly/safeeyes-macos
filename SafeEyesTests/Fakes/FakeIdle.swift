// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation
@testable import SafeEyes

public final class FakeIdle: IdleProviding {
    public var currentIdleSeconds: TimeInterval

    public init(initialIdleSeconds: TimeInterval = 0) {
        self.currentIdleSeconds = initialIdleSeconds
    }

    public func secondsSinceLastInput() -> TimeInterval {
        currentIdleSeconds
    }
}
