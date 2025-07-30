//
//  MockDrawingCurve.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import Combine
import Foundation
import UIKit

final class MockDrawingCurve: Iterator<GrayscaleDotPoint>, DrawingCurve {

    let touchPhase = CurrentValueSubject<UITouch.Phase, Never>(.cancelled)

    var currentCurvePoints: [GrayscaleDotPoint] = []

    func append(points: [GrayscaleDotPoint], touchPhase: UITouch.Phase) {}

    override func reset() {}
}
