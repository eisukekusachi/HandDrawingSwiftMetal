//
//  Transforming.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

class Transforming: TransformingProtocol {

    private var storedMatrix: CGAffineTransform = CGAffineTransform.identity

    private var touchesA: TransformingData?
    private var touchesB: TransformingData?

    var hashValues: [TouchHashValue] {
        [touchesA?.hashValue,
         touchesB?.hashValue].compactMap { $0 }
    }

    /// When a gesture is determined to be `transforming`, the touchManager manages two fingers
    func setHashValueIfNil(_ touchManager: TouchManager) {
        guard
            touchesA == nil,
            touchesB == nil,
            let firstHashValue = touchManager.touchPointsDictionary.keys.sorted().first,
            let lastHashValue = touchManager.touchPointsDictionary.keys.sorted().last
        else { return }

        touchesA = TransformingData(hashValue: firstHashValue)
        touchesB = TransformingData(hashValue: lastHashValue)
    }

    func getMatrix(_ matrix: CGAffineTransform) -> CGAffineTransform {
        storedMatrix.concatenating(matrix)
    }

    func updateTouches(_ touchManager: TouchManager) {
        guard
            let touchesA,
            let touchesB,
            let touchPointA = touchManager.touchPointsDictionary[touchesA.hashValue]?.last,
            let touchPointB = touchManager.touchPointsDictionary[touchesB.hashValue]?.last
        else { return }

        touchesA.updatePoint(touchPointA.location)
        touchesB.updatePoint(touchPointB.location)
    }

    func updateMatrix(_ matrix: CGAffineTransform) {
        storedMatrix = matrix
    }

    /// Generate a matrix from touch points and the view center point.
    func makeMatrix(
        frameCenter: CGPoint
    ) -> CGAffineTransform? {
        guard
            let touchesAPoints = touchesA?.touches,
            let touchesBPoints = touchesB?.touches
        else { return nil }

        return CGAffineTransform.makeMatrix(
            center: frameCenter,
            pointsA: touchesAPoints,
            pointsB: touchesBPoints,
            counterRotate: true,
            flipY: true
        )
    }

    func clear() {
        touchesA = nil
        touchesB = nil
    }

}
