import Foundation
import os

@MainActor
public final class LoggingOverlay: OverlayPresenting {
    public init() {}

    public func show(kind: BreakKind, strict: Bool) {
        Log.overlay.info("LoggingOverlay: show break kind=\(kind.rawValue, privacy: .public), strict=\(strict, privacy: .public)")
    }

    public func hide() {
        Log.overlay.info("LoggingOverlay: hide")
    }
}
