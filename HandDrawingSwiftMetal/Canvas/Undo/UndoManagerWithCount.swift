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

    let refreshUndoComponentsObjectSubject = PassthroughSubject<Void, Never>()

    private (set) var undoCount: Int = 0
    private (set) var redoCount: Int = 0

    override init() {
        super.init()
        clear()
    }

    func incrementUndoCount() {
        if undoCount < levelsOfUndo {
            undoCount += 1
            redoCount = 0
            refreshUndoComponentsObjectSubject.send()
        }
    }

    @discardableResult
    func performUndo() -> Bool {
        if canUndo {
            undo()

            undoCount -= 1
            redoCount += 1
            refreshUndoComponentsObjectSubject.send()

            return true
        }
        return false
    }
    @discardableResult
    func performRedo() -> Bool {
        if canRedo {
            redo()

            undoCount += 1
            redoCount -= 1
            refreshUndoComponentsObjectSubject.send()

            return true
        }
        return false
    }

    func clear() {
        removeAllActions()

        undoCount = 0
        redoCount = 0
        refreshUndoComponentsObjectSubject.send()
    }
}
