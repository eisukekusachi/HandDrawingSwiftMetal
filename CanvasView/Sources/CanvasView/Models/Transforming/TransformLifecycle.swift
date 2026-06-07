//
//  TransformLifecycle.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/07.
//

/// Lifecycle of canvas pan/pinch
public enum TransformLifecycle: Equatable, Sendable {
    case idle
    case transforming
    case finalizing

    /// `true` while transforming or committing
    public var isActive: Bool {
        switch self {
        case .idle:
            false
        case .transforming, .finalizing:
            true
        }
    }
}
