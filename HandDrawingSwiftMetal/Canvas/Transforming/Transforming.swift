//
//  Transforming.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit
import Combine

/// A class for view rotation.
class Transforming {

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

    var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    var screenCenter: CGPoint = .zero

    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    func setMatrix(_ matrix: CGAffineTransform) {
        matrixSubject.send(matrix)
        storedMatrix = matrix
        touchPointA = nil
        touchPointB = nil
    }

}

extension Transforming {

    var isCurrentKeysNil: Bool {
        keyA == nil || keyB == nil
    }

    func initTransforming(_ dictionary: [TouchHashValue: [TouchPoint]]) {
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

    func transformCanvas(_ dictionary: [TouchHashValue: [TouchPoint]]) {
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

extension Transforming {

    private func updateCurrentKeys(
        from dictionary: [TouchHashValue: [TouchPoint]]
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
