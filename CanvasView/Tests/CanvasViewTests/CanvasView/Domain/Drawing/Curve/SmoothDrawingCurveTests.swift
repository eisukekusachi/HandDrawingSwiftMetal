//
//  SmoothDrawingCurveTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import CanvasView
import XCTest

@testable import CanvasView

final class SmoothDrawingCurveTests: XCTestCase {

    @MainActor
    func testIsDrawingFinished() {
        let subject = SmoothDrawingCurve()

        subject.touchPhase.send(.began)
        XCTAssertFalse(subject.isDrawingFinished)
        XCTAssertTrue(subject.isCurrentlyDrawing)

        subject.touchPhase.send(.moved)
        XCTAssertFalse(subject.isDrawingFinished)
        XCTAssertTrue(subject.isCurrentlyDrawing)

        subject.touchPhase.send(.ended)
        XCTAssertTrue(subject.isDrawingFinished)
        XCTAssertFalse(subject.isCurrentlyDrawing)

        subject.touchPhase.send(.cancelled)
        XCTAssertTrue(subject.isDrawingFinished)
        XCTAssertFalse(subject.isCurrentlyDrawing)
    }

    @MainActor
    func testIsFirstCurveNeeded() {
        let subject = SmoothDrawingCurve()

        subject.append([
            .generate(),
            .generate()
        ])
        XCTAssertFalse(subject.isFirstCurveNeeded)

        // After creating the instance, it becomes `true` when three elements are stored in the array.
        subject.append([
            .generate()
        ])
        XCTAssertTrue(subject.isFirstCurveNeeded)

        // The value of the first curve is retrieved only once
        _ = subject.currentCurvePoints
        XCTAssertFalse(subject.isFirstCurveNeeded)
    }

    @MainActor
    func testAppendToIterator() {
        let subject = SmoothDrawingCurve()

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
