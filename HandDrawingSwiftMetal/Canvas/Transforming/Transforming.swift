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

    func finishTransforming() {
        storedMatrix = matrixSubject.value
        touchPointsA = nil
        touchPointsB = nil
    }

    func clearTransforming() {
        matrixSubject.value = storedMatrix
        touchPointsA = nil
        touchPointsB = nil
    }

}
