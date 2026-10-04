// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation

public struct SystemTimeSource: TimeSource {
    public init() {}

    public var now: Date {
        Date()
    }
}
