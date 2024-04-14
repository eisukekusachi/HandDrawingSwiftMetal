//
//  DrawingLineProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/04.
//

import UIKit

protocol DrawingLineProtocol {

    var hashValue: TouchHashValue? { get }
    var iterator: Iterator<DotPoint> { get }

    func initDrawing(hashValue: TouchHashValue)

    func appendToIterator(
        _ points: [DotPoint]
    )

    func makeLineSegment(
        with parameters: LineParameters,
        phase: UITouch.Phase
    ) -> LineSegment

    func finishDrawing()

}
