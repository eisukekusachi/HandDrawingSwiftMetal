//
//  MockDrawingCurveIterator.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import Combine
import Foundation
import XCTest
@testable import HandDrawingSwiftMetal

final class MockDrawingCurveIterator: Iterator<GrayscaleDotPoint>, SingleCurveIterator {

    var iterator: Iterator<GrayscaleDotPoint> = .init()

    let touchPhase = CurrentValueSubject<UITouch.Phase, Never>(.cancelled)

    var latestCurvePoints: [GrayscaleDotPoint] = []

    func append(points: [GrayscaleDotPoint], touchPhase: UITouch.Phase) {}

    override func reset() {}

}
