//
//  MockDrawingCurveIterator.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Foundation
@testable import HandDrawingSwiftMetal

final class MockDrawingCurveIterator: Iterator<GrayscaleDotPoint>, DrawingCurveIterator {

    var iterator: Iterator<GrayscaleDotPoint> = .init()

    var touchPhase: UITouch.Phase = .began

    var hasArrayThreeElementsButNoFirstCurveCreated: Bool = false

    func appendToIterator(points: [GrayscaleDotPoint], touchPhase: UITouch.Phase) {}

    override func reset() {}

}
