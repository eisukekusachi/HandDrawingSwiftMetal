//
//  InputManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/19.
//

import Foundation

enum InputType {
    case ready
    case pencil
    case finger
}

/// Manage GestureWithStorage
class InputManager {

    private (set) var currentInput: InputType = .ready

    /// Updates the current input.
    /// If the current input is a pencil, just return it.
    @discardableResult
    func updateCurrentInput(_ input: InputType) -> InputType {
        // Check if the current input is a pencil.
        if currentInput == .pencil {
            return currentInput

        } else {
            // Set the current input to the new input and return it.
            currentInput = input
            return currentInput
        }
    }

    func reset() {
        currentInput = .ready
    }

}
