//
//  CanvasTransformer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit
import Combine

/// A class for view rotation.
class CanvasTransformer {

    var matrix: CGAffineTransform {
        matrixSubject.value
    }

    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> {
        matrixSubject.eraseToAnyPublisher()
    }

    private var keyA: TouchHashValue?
    private var keyB: TouchHashValue?
    private var touchPointA: CGPoint?
    private var touchPointB: CGPoint?

    private var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

}

extension CanvasTransformer {

    var isCurrentKeysNil: Bool {
        keyA == nil || keyB == nil
    }

    func initTransforming(_ dictionary: [TouchHashValue: [CanvasTouchPoint]]) {
        updateCurrentKeys(from: dictionary)

        guard
            let keyA,
            let keyB,
            let pointA = dictionary[keyA]?.first?.location,
            let pointB = dictionary[keyB]?.first?.location
        else { return }

        touchPointA = pointA
        touchPointB = pointB
    }

    func transformCanvas(screenCenter: CGPoint, _ dictionary: [TouchHashValue: [CanvasTouchPoint]]) {
        guard
            let keyA,
            let keyB,
            let touchPointA,
            let touchPointB,
            let lastTouchPointA = dictionary[keyA]?.last?.location,
            let lastTouchPointB = dictionary[keyB]?.last?.location,
            let newMatrix = CGAffineTransform.makeMatrix(
                center: screenCenter,
                pointsA: (touchPointA, lastTouchPointA),
                pointsB: (touchPointB, lastTouchPointB),
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
        touchPointA = nil
        touchPointB = nil
    }

    func finishTransforming() {
        storedMatrix = matrixSubject.value
        keyA = nil
        keyB = nil
        touchPointA = nil
        touchPointB = nil
    }

    func reset() {
        matrixSubject.value = storedMatrix
        keyA = nil
        keyB = nil
        touchPointA = nil
        touchPointB = nil
    }

}

extension CanvasTransformer {

    private func updateCurrentKeys(
        from dictionary: [TouchHashValue: [CanvasTouchPoint]]
    ) {
        guard
            dictionary.count == 2,
            let firstHashValue = dictionary.keys.sorted().first,
            let lastHashValue = dictionary.keys.sorted().last
        else { return }

        keyA = firstHashValue
        keyB = lastHashValue
    }

}
