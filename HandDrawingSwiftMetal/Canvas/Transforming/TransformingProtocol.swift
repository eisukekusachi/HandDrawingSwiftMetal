//
//  TransformingProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import Foundation

protocol TransformingProtocol {

    var hashValues: [TouchHashValue] { get }

    /// When a gesture is determined to be `transforming`, the touchManager manages two fingers
    func setHashValueIfNil(_ touchManager: TouchManager)

    func updateTouches(_ touchManager: TouchManager)

    func getMatrix(_ matrix: CGAffineTransform) -> CGAffineTransform

    func makeMatrix(frameCenter: CGPoint) -> CGAffineTransform?

    func updateMatrix(_ matrix: CGAffineTransform)

    func clear()

}
