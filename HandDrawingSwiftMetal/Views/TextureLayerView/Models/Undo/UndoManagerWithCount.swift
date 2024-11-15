//
//  UndoManagerWithCount.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/18.
//

import Foundation
import Combine

/// An undoManager with undoCount and redoCount
class UndoManagerWithCount: UndoManager {

    private (set) var undoNumber: Int = 0
    private (set) var redoNumber: Int = 0

    override init() {
        super.init()
        reset()
    }

    func incrementUndoCount() {
        if undoNumber < levelsOfUndo {
            undoNumber += 1
            redoNumber = 0
        }
    }

    @discardableResult
    func performUndo() -> Bool {
        if canUndo {
            undo()

            undoNumber -= 1
            redoNumber += 1

            return true
        }
        return false
    }
    @discardableResult
    func performRedo() -> Bool {
        if canRedo {
            redo()

            undoNumber += 1
            redoNumber -= 1

            return true
        }
        return false
    }

    func reset() {
        removeAllActions()

        undoNumber = 0
        redoNumber = 0
    }

}
