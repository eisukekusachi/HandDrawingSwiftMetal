//
//  GrayscaleCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

protocol GrayscaleCurve {

    var iterator: GrayscaleTexturePointIterator { get }

    /// A variable used to get elements from the array starting from the next element after this point
    var startAfterPoint: TouchPoint? { get set }

    /// The key currently used in the Dictionary
    var currentDictionaryKey: TouchHashValue? { get set }

    func appendToIterator(
        points: [GrayscaleTexturePoint],
        touchPhase: UITouch.Phase
    )

    func makeCurvePointsFromIterator(
        touchPhase: UITouch.Phase
    ) -> [GrayscaleTexturePoint]

    func reset()

}
