// Copyright (c) slgobinath (Original Architecture)
// Copyright (c) 2026 Mohamed Elgebaly (macOS Native Port)

import Foundation

@MainActor
public protocol OverlayPresenting: AnyObject {
    func show(kind: BreakKind, strict: Bool)
    func hide()
}
