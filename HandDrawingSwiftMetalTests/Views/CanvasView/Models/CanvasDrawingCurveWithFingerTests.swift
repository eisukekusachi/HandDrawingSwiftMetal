//
//  CanvasDrawingCurveWithFingerTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasDrawingCurveWithFingerTests: XCTestCase {

    func testHasArrayThreeElementsButNoFirstCurveCreated() {
        let subject = CanvasDrawingCurveWithFinger()

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

    func testAppendToIterator() {
        let subject = CanvasDrawingCurveWithFinger()

        subject.appendToIterator(points: [.generate(location: .init(x: 0, y: 0))], touchPhase: .began)
        subject.appendToIterator(points: [.generate(location: .init(x: 2, y: 2))], touchPhase: .moved)
        subject.appendToIterator(points: [.generate(location: .init(x: 4, y: 4))], touchPhase: .moved)
        subject.appendToIterator(points: [.generate(location: .init(x: 6, y: 6))], touchPhase: .ended)

        XCTAssertEqual(subject.tmpIterator.array[0].location, .init(x: 0, y: 0))
        XCTAssertEqual(subject.tmpIterator.array[1].location, .init(x: 2, y: 2))
        XCTAssertEqual(subject.tmpIterator.array[2].location, .init(x: 4, y: 4))
        XCTAssertEqual(subject.tmpIterator.array[3].location, .init(x: 6, y: 6))

        /// The first point is added as it is
        XCTAssertEqual(subject.iterator.array[0].location, .init(x: 0, y: 0))

        /// The average of the two points is added for all other points
        XCTAssertEqual(subject.iterator.array[1].location, .init(x: 1, y: 1))
        XCTAssertEqual(subject.iterator.array[2].location, .init(x: 3, y: 3))
        XCTAssertEqual(subject.iterator.array[3].location, .init(x: 5, y: 5))

        /// The last point is added as it is
        XCTAssertEqual(subject.iterator.array[4].location, .init(x: 6, y: 6))
    }

}
