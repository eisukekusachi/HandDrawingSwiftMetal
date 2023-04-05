//
//  ActionStateManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/04.
//

import Foundation

class ActionStateManager {
    
    private (set) var currentState: ActionState = .recognizing
    
    func update(_ value: ActionState) {
        if currentState != .recognizing {
            return
        }
        currentState = value
    }
    
    func reset() {
        currentState = .recognizing
    }
}
