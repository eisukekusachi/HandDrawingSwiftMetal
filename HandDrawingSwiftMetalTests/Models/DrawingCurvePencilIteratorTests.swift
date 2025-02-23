//
//  DrawingCurvePencilIteratorTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class DrawingCurvePencilIteratorTests: XCTestCase {

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

}
