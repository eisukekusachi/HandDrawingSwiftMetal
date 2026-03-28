//
//  UndoRedoButtonState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/14.
//

import Foundation

/// A struct that manages and configures the display of the Undo/Redo buttons
@MainActor
struct UndoRedoButtonState: Sendable {
    let isUndoEnabled: Bool
    let isRedoEnabled: Bool

    init(_ undoManager: UndoManager) {
        isUndoEnabled = undoManager.canUndo
        isRedoEnabled = undoManager.canRedo
    }
}
