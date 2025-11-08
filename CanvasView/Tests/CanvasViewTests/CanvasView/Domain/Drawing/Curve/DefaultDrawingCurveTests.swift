//
//  DefaultDrawingCurveTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import Testing

@testable import CanvasView

struct DefaultDrawingCurveTests {

    private typealias Subject = DefaultDrawingCurve

    func testIsDrawingFinished() {
        let subject = Subject()

        subject.touchPhase.send(.began)
        #expect(subject.isDrawingFinished == false)
        #expect(subject.isCurrentlyDrawing == true)
        //XCTAssertFalse(subject.isDrawingFinished)
        //XCTAssertTrue(subject.isCurrentlyDrawing)

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

    func testIsFirstCurveNeeded() {
        let subject = Subject()

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
}
