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
}

public extension StrokeLifecycle {
    /// `true` while drawing or committing.
    var isActive: Bool {
        switch self {
        case .idle:
            false
        case .drawing, .finalizing:
            true
        }
    }

    /// `true` while the stroke is being drawn.
    var isDrawing: Bool {
        self == .drawing
    }
}
