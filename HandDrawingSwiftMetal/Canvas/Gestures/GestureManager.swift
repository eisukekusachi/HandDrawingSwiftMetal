//
//  GestureManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/02.
//

import UIKit

class GestureManager {
    private (set) var currentGesture: GestureProtocol?

    /// If the current gesture is a PencilGestureRecognizer, return it as is without any updates..
    @discardableResult
    func update(_ gesture: GestureProtocol) -> GestureProtocol? {
        // Check if the current gesture is a PencilGestureRecognizer.
        if currentGesture is PencilGesture {
            return currentGesture

        } else {
            // Set the current gesture to the new gesture and return it.
            currentGesture = gesture
            return currentGesture
        }
    }

    func clear() {
        currentGesture = nil
    }
}
