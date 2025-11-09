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
    var touchPhase: TouchPhase = .cancelled

    func isFirstCurveNeeded() -> Bool {
        return false
    }

    func append(points: [GrayscaleDotPoint], touchPhase: TouchPhase) {}

    override func reset() {}
}
