//
//  TransformLifecycle.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/07.
//

import Foundation

/// Lifecycle of canvas pan/pinch: idle → transforming → finalizing → idle.
public enum TransformLifecycle: Equatable, Sendable {
    case idle
    case transforming
    case finalizing

    /// `true` while transforming or committing (UI should stay locked)
    public var isActive: Bool {
        switch self {
        case .idle:
            false
        case .transforming, .finalizing:
            true
        }
    }
}
