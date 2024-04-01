//
//  ActionManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/01.
//

import Foundation

final class ActionManager {

    private (set) var state: ActionState = .recognizing

    func updateState(_ newState: ActionState) -> ActionState {
        if state == .recognizing {
            state = newState
        }
        return state
    }

    func reset() {
        state = .recognizing
    }

}
