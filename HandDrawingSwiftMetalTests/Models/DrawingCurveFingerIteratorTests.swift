//
//  DrawingCurveFingerIteratorTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class DrawingCurveFingerIteratorTests: XCTestCase {

    func testIsDrawingFinished() {
        let subject = DrawingCurveFingerIterator()

        subject.touchPhase = .began
        XCTAssertFalse(subject.isDrawingFinished)
        XCTAssertTrue(subject.isCurrentlyDrawing)

        subject.touchPhase = .moved
        XCTAssertFalse(subject.isDrawingFinished)
        XCTAssertTrue(subject.isCurrentlyDrawing)

        subject.touchPhase = .ended
        XCTAssertTrue(subject.isDrawingFinished)
        XCTAssertFalse(subject.isCurrentlyDrawing)

        subject.touchPhase = .cancelled
        XCTAssertTrue(subject.isDrawingFinished)
        XCTAssertFalse(subject.isCurrentlyDrawing)
    }

    func testShouldGetFirstCurve() {
        let subject = DrawingCurveFingerIterator()

        subject.append([
            .generate(),
            .generate()
        ])
        XCTAssertFalse(subject.shouldGetFirstCurve)

        // After creating the instance, it becomes `true` when three elements are stored in the array.
        subject.append([
            .generate()
        ])
        XCTAssertTrue(subject.shouldGetFirstCurve)

        // The value of the first curve is retrieved only once
        _ = subject.latestCurvePoints
        XCTAssertFalse(subject.shouldGetFirstCurve)
    }

    func testAppendToIterator() {
        let subject = DrawingCurveFingerIterator()

        subject.append(points: [.generate(location: .init(x: 0, y: 0))], touchPhase: .began)
        subject.append(points: [.generate(location: .init(x: 2, y: 2))], touchPhase: .moved)
        subject.append(points: [.generate(location: .init(x: 4, y: 4))], touchPhase: .moved)
        subject.append(points: [.generate(location: .init(x: 6, y: 6))], touchPhase: .ended)

        XCTAssertEqual(subject.tmpIterator.array[0].location, .init(x: 0, y: 0))
        XCTAssertEqual(subject.tmpIterator.array[1].location, .init(x: 2, y: 2))
        XCTAssertEqual(subject.tmpIterator.array[2].location, .init(x: 4, y: 4))
        XCTAssertEqual(subject.tmpIterator.array[3].location, .init(x: 6, y: 6))

        /// The first point is added as it is
        XCTAssertEqual(subject.array[0].location, .init(x: 0, y: 0))

        /// The average of the two points is added for all other points
        XCTAssertEqual(subject.array[1].location, .init(x: 1, y: 1))
        XCTAssertEqual(subject.array[2].location, .init(x: 3, y: 3))
        XCTAssertEqual(subject.array[3].location, .init(x: 5, y: 5))

        /// The last point is added as it is
        XCTAssertEqual(subject.array[4].location, .init(x: 6, y: 6))
    }

}
