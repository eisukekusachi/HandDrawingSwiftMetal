//
//  UndoRedoButtonState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/14.
//

import Foundation

/// A struct that manages and configures the display of the Undo/Redo buttons
@MainActor
public struct UndoRedoButtonState: Sendable {
    public let isUndoEnabled: Bool
    public let isRedoEnabled: Bool

    public init(_ undoManager: UndoManager) {
        isUndoEnabled = undoManager.canUndo
        isRedoEnabled = undoManager.canRedo
    }
}
