//
//  Transforming.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit
import Combine

/// A class that manages canvas transformations
final class Transforming {

    private(set) var matrix: CGAffineTransform = CGAffineTransform.identity

    private var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    private var firstKey: TouchID?
    private var firstFirstTouchPoint: CGPoint?

    private var secondKey: TouchID?
    private var secondFirstTouchPoint: CGPoint?
}

extension Transforming {

    var isKeysInitialized: Bool {
        firstKey != nil && secondKey != nil
    }

    var isNotKeysInitialized: Bool {
        !isKeysInitialized
    }

    func initialize(_ touchHistories: TouchHistoriesOnScreen) {
        guard touchHistories.count == 2 else { return }

        let keys = Array(touchHistories.keys)

        guard
            let firstPoint = touchHistories[keys[0]]?.last?.location,
            let secondPoint = touchHistories[keys[1]]?.last?.location
        else { return }

        self.firstKey = keys[0]
        self.firstFirstTouchPoint = firstPoint

        self.secondKey = keys[1]
        self.secondFirstTouchPoint = secondPoint
    }

    func transformCanvas(screenCenter: CGPoint, touchHistories: TouchHistoriesOnScreen) {
        guard
            touchHistories.count == 2,
            let firstKey,
            let secondKey,
            let firstFirstTouchPoint,
            let secondFirstTouchPoint,
            let firstLastTouchPoint = touchHistories[firstKey]?.last?.location,
            let secondLastTouchPoint = touchHistories[secondKey]?.last?.location,
            let newMatrix = CGAffineTransform.makeMatrix(
                center: screenCenter,
                pointsA: (firstLastTouchPoint, firstFirstTouchPoint),
                pointsB: (secondLastTouchPoint, secondFirstTouchPoint),
                counterRotate: true,
                flipY: true
            )
        else { return }

        matrix = storedMatrix.concatenating(newMatrix)
    }

    func setMatrix(_ matrix: CGAffineTransform) {
        self.matrix = matrix
        self.storedMatrix = matrix
        resetParameters()
    }

    func resetMatrix() {
        self.matrix = storedMatrix
        resetParameters()
    }

    func endTransformation() {
        self.storedMatrix = matrix
        resetParameters()
    }
}

extension Transforming {

    private func resetParameters() {
        firstKey = nil
        secondKey = nil
        firstFirstTouchPoint = nil
        secondFirstTouchPoint = nil
    }
}
