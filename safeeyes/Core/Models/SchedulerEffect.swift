// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation

public enum SchedulerEffect: Equatable {
    case scheduleNotification(kind: BreakKind, leadSeconds: TimeInterval)
    case cancelNotification
    case showOverlay(kind: BreakKind, strict: Bool)
    case hideOverlay
    case playEndChime
    case stateChanged
}
