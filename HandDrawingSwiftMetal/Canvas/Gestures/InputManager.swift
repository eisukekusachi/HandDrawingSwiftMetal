//
//  InputManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/02.
//

import UIKit

class InputManager {
    private (set) var currentInput: InputProtocol?

    /// Updates the current input.
    /// If the current input is a PencilInput, return it as is without any updates.
    @discardableResult
    func updateInput(_ input: InputProtocol) -> InputProtocol? {
        // Check if the current input is a PencilInput.
        if currentInput is PencilInput {
            return currentInput

        } else {
            // Set the current input to the new input and return it.
            currentInput = input
            return currentInput
        }
    }

    func clear() {
        currentInput = nil
    }
}
