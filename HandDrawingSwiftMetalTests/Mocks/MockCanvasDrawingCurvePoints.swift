//
//  MockCanvasDrawingCurvePoints.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Foundation
@testable import HandDrawingSwiftMetal

final class MockCanvasDrawingCurvePoints: CanvasDrawingCurvePoints {

    var iterator: Iterator<GrayscaleDotPoint> = .init()

    var currentTouchPhase: UITouch.Phase = .began

    var hasArrayThreeElementsButNoFirstCurveCreated: Bool = false

    func appendToIterator(points: [T], touchPhase: UITouch.Phase) {}

    func reset() {}

}
