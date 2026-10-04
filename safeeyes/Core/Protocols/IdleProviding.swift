// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation

public protocol IdleProviding {
    func secondsSinceLastInput() -> TimeInterval
}
