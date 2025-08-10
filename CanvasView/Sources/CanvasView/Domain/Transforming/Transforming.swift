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

    var matrix: CGAffineTransform {
        matrixSubject.value
    }

    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> {
        matrixSubject.eraseToAnyPublisher()
    }
    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    private var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    private var keyA: TouchID?
    private var keyB: TouchID?
    private var firstTouchPointA: CGPoint?
    private var firstTouchPointB: CGPoint?
}

extension Transforming {

    var isKeysInitialized: Bool {
        keyA != nil && keyB != nil
    }

    var isNotKeysInitialized: Bool {
        !isKeysInitialized
    }

    func initialize(_ touchHistories: TouchHistoriesOnScreen) {
        guard
            touchHistories.count == 2,
            let keyA = touchHistories.keys.sorted().first,
            let keyB = touchHistories.keys.sorted().last,
            let pointA = touchHistories[keyA]?.first?.location,
            let pointB = touchHistories[keyB]?.first?.location
        else { return }

        self.keyA = keyA
        self.keyB = keyB
        self.firstTouchPointA = pointA
        self.firstTouchPointB = pointB
    }

    func transformCanvas(screenCenter: CGPoint, touchHistories: TouchHistoriesOnScreen) {
        guard
            touchHistories.count == 2,
            let keyA,
            let keyB,
            let firstTouchPointA,
            let firstTouchPointB,
            let lastTouchPointA = touchHistories[keyA]?.last?.location,
            let lastTouchPointB = touchHistories[keyB]?.last?.location,
            let newMatrix = CGAffineTransform.makeMatrix(
                center: screenCenter,
                pointsA: (firstTouchPointA, lastTouchPointA),
                pointsB: (firstTouchPointB, lastTouchPointB),
                counterRotate: true,
                flipY: true
            )
        else { return }

        matrixSubject.send(
            storedMatrix.concatenating(newMatrix)
        )
    }

    func setMatrix(_ matrix: CGAffineTransform) {
        matrixSubject.send(matrix)
        storedMatrix = matrix
        resetParameters()
    }

    func resetMatrix() {
        matrixSubject.value = storedMatrix
        resetParameters()
    }

    func endTransformation() {
        storedMatrix = matrixSubject.value
        resetParameters()
    }
}

extension Transforming {

    private func resetParameters() {
        keyA = nil
        keyB = nil
        firstTouchPointA = nil
        firstTouchPointB = nil
    }
}
