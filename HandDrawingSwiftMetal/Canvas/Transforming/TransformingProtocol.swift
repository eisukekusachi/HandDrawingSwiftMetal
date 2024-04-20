//
//  TransformingProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import Foundation
import Combine

/// A protocol for view rotation.
/// It's used to create an AffineTransform from the initial and final positions of two fingers, the center point of the screen.
protocol TransformingProtocol {

    var touchPointsA: TransformingPoint? { get }
    var touchPointsB: TransformingPoint? { get }
    var screenCenter: CGPoint { get set }

    var matrix: CGAffineTransform { get }
    var matrixPublisher: AnyPublisher<CGAffineTransform, Never> { get }
    var storedMatrix: CGAffineTransform { get }

    func initTransforming(hashValues: (TouchHashValue, TouchHashValue))

    func setMatrix(_ matrix: CGAffineTransform)

    func transformCanvas(touchPoints: (TouchPoint, TouchPoint))

    func finishTransforming()

}

extension TransformingProtocol {

    func getHashValues(
        from touchManager: TouchManager
    ) -> (TouchHashValue, TouchHashValue)? {
        guard
            touchManager.touchPointsDictionary.count == 2,
            let firstHashValue = touchManager.touchPointsDictionary.keys.sorted().first,
            let lastHashValue = touchManager.touchPointsDictionary.keys.sorted().last
        else { return nil }

        return (firstHashValue, lastHashValue)
    }

    func getTouchPoints(
        from touchManager: TouchManager,
        using hashValues: (TouchHashValue, TouchHashValue)
    ) -> (TouchPoint, TouchPoint)? {
        guard
            touchManager.touchPointsDictionary.count == 2,
            let touchPointA = touchManager.touchPointsDictionary[hashValues.0]?.last,
            let touchPointB = touchManager.touchPointsDictionary[hashValues.1]?.last
        else { return nil }

        return (touchPointA, touchPointB)
    }

}
