//
//  StrokeLifecycle.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/15.
//

/// Lifecycle of a stroke session.
public enum StrokeLifecycle: Equatable, Sendable {
    case idle
    case drawing
    case finalizing(cancelled: Bool)

    /// `true` while drawing or committing (UI should stay locked)
    public var isActive: Bool {
        switch self {
        case .idle:
            false
        case .drawing, .finalizing:
            true
        }
    }
}
