//
//  GestureManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/02.
//

import UIKit

enum TouchState {
    case ready
    case began
    case moved
    case ended
}

class InputManager {
    
    private (set) var currentInput: UIGestureRecognizer?
    
    func update(_ value: UIGestureRecognizer?) {
        if currentInput is PencilGestureRecognizer {
            return
        }
        
        currentInput = value
    }
    
    func reset() {
        currentInput = nil
    }
}
