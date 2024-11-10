//
//  CanvasPencilDrawingCurvePointsTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasPencilDrawingCurvePointsTests: XCTestCase {

    func testHasArrayThreeElementsButNoFirstCurveCreated() {
        let subject = CanvasPencilDrawingCurvePoints()

        subject.appendToIterator(points: [.generate()], touchPhase: .began)
        XCTAssertFalse(subject.hasArrayThreeElementsButNoFirstCurveCreated)

        subject.appendToIterator(points: [.generate()], touchPhase: .moved)
        XCTAssertFalse(subject.hasArrayThreeElementsButNoFirstCurveCreated)

        /// Return true only once when 3 points are stored
        subject.appendToIterator(points: [.generate()], touchPhase: .moved)
        XCTAssertTrue(subject.hasArrayThreeElementsButNoFirstCurveCreated)

        subject.appendToIterator(points: [.generate()], touchPhase: .moved)
        XCTAssertFalse(subject.hasArrayThreeElementsButNoFirstCurveCreated)
    }

}
