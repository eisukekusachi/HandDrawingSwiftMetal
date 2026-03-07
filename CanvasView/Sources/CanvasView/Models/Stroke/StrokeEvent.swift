//
//  StrokeEvent.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/02/11.
//

import Foundation

/// Events representing the lifecycle of a drawing stroke
public enum StrokeEvent {
    /// Indicates that a finger-based stroke has begun
    case fingerStrokeBegan

    /// Indicates that an Apple Pencil stroke has begun
    case pencilStrokeBegan

    /// Indicates that the current stroke has finished successfully
    case strokeCompleted

    /// Indicates that the current stroke was cancelled before completion
    case strokeCancelled
}
