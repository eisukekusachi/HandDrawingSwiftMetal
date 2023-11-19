//
//  InputManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/02.
//

import UIKit

/// Manage GestureWithStorage
class InputManager {
    private (set) var currentInput: GestureWithStorageProtocol?

    /// Updates the current input.
    /// If the current input is a Pencil, return it as is without any updates.
    @discardableResult
    func updateInput(_ input: GestureWithStorageProtocol) -> GestureWithStorageProtocol? {
        // Check if the current input is a Pencil.
        if currentInput is PencilGestureWithStorage {
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
