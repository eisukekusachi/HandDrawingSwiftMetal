//
//  ActionStateManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/04.
//

import Foundation

class ActionStateManager {
    private (set) var state: ActionState = .recognizing

    func update(_ newState: ActionState) {
        if state != .recognizing {
            return
        }
        state = newState
    }

    func reset() {
        state = .recognizing
    }
}

extension ActionStateManager {
    static func getState(touchPoints: [Int: [TouchPoint]]) -> ActionState {
        var result: ActionState = .recognizing

        if let actionState = ActionState.isDrawingGesture(touchPoints: touchPoints) {
            result = actionState

        } else if let actionState = ActionState.isTransformingGesture(touchPoints: touchPoints) {
            result = actionState
        }

        return result
    }
}
