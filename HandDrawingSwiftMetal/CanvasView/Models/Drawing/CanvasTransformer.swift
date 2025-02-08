//
//  CanvasTransformer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit
import Combine

/// A class for canvas rotation
final class CanvasTransformer {

    var matrix: CGAffineTransform {
        matrixSubject.value
    }

    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> {
        matrixSubject.eraseToAnyPublisher()
    }
    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    private var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    private var keyA: CanvasTouchHashValue?
    private var keyB: CanvasTouchHashValue?
    private var firstTouchPointA: CGPoint?
    private var firstTouchPointB: CGPoint?

}

extension CanvasTransformer {

    var isKeysInitialized: Bool {
        keyA != nil && keyB != nil
    }

    func initTransformingIfNeeded(_ dictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) {
        guard
            !isKeysInitialized,
            dictionary.count == 2,
            let keyA = dictionary.keys.sorted().first,
            let keyB = dictionary.keys.sorted().last,
            let pointA = dictionary[keyA]?.first?.location,
            let pointB = dictionary[keyB]?.first?.location
        else { return }

        self.keyA = keyA
        self.keyB = keyB
        self.firstTouchPointA = pointA
        self.firstTouchPointB = pointB
    }

    func transformCanvas(screenCenter: CGPoint, _ dictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) {
        guard
            dictionary.count == 2,
            let keyA,
            let keyB,
            let firstTouchPointA,
            let firstTouchPointB,
            let lastTouchPointA = dictionary[keyA]?.last?.location,
            let lastTouchPointB = dictionary[keyB]?.last?.location,
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

    func finishTransforming() {
        storedMatrix = matrixSubject.value
        resetParameters()
    }

}

extension CanvasTransformer {

    private func resetParameters() {
        keyA = nil
        keyB = nil
        firstTouchPointA = nil
        firstTouchPointB = nil
    }

}
