//
//  Transforming.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit
import Combine

/// A class for view rotation.
class Transforming: TransformingProtocol {

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

    var touchPointsA: TransformingPoint?
    var touchPointsB: TransformingPoint?
    var screenCenter: CGPoint = .zero

    var isInitializationRequired: Bool {
        touchPointsA == nil ||
        touchPointsB == nil
    }

    var isTouchEnded: Bool {
        let phases = [
        touchPointsA?.startTouchPoint?.phase,
        touchPointsA?.lastTouchPoint?.phase,
        touchPointsB?.startTouchPoint?.phase,
        touchPointsB?.lastTouchPoint?.phase]

        return phases.contains(.ended) || phases.contains(.cancelled)
    }

    private let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    func initTransforming(hashValues: (TouchHashValue, TouchHashValue)) {
        touchPointsA = TransformingPoint(hashValue: hashValues.0)
        touchPointsB = TransformingPoint(hashValue: hashValues.1)
    }

    func setMatrix(_ matrix: CGAffineTransform) {
        matrixSubject.send(matrix)
        storedMatrix = matrix
        touchPointsA = nil
        touchPointsB = nil
        touchPointA = nil
        touchPointB = nil
    }

    func transformCanvas(touchPoints: (TouchPoint, TouchPoint)) {
        touchPointsA?.updateTouchPoints(touchPoints.0)
        touchPointsB?.updateTouchPoints(touchPoints.1)

        guard
            let startAndLastLocationA = touchPointsA?.startAndLastLocations,
            let startAndLastLocationB = touchPointsB?.startAndLastLocations,
            let newMatrix = CGAffineTransform.makeMatrix(
                center: screenCenter,
                pointsA: startAndLastLocationA,
                pointsB: startAndLastLocationB,
                counterRotate: true,
                flipY: true
            )
        else { return }

        matrixSubject.send(storedMatrix.concatenating(newMatrix))
    }

    func clearTransforming() {
        matrixSubject.value = storedMatrix
        touchPointsA = nil
        touchPointsB = nil
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
        touchPointsA = nil
        touchPointsB = nil
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
