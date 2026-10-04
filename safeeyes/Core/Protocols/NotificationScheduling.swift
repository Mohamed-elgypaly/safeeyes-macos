// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation

public protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleBreakNotice(kind: BreakKind, leadSeconds: TimeInterval)
    func cancel()
}
