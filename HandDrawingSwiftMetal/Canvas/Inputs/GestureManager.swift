//
//  GestureManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/02.
//

import UIKit

class GestureManager {
    private (set) var currentGesture: UIGestureRecognizer?

    /// If the current gesture is a PencilGestureRecognizer, return it as is without any updates..
    @discardableResult
    func update(_ gesture: UIGestureRecognizer) -> UIGestureRecognizer? {
        // Check if the current gesture is a PencilGestureRecognizer.
        if currentGesture is PencilGestureRecognizer {
            return currentGesture

        } else {
            // Set the current gesture to the new gesture and return it.
            currentGesture = gesture
            return currentGesture
        }
    }

    // Function to reset the current gesture to nil.
    func reset() {
        currentGesture = nil
    }
}
