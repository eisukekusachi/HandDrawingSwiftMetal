//
//  CanvasPencilDrawingArraysTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasPencilDrawingArraysTests: XCTestCase {

    func testHasArrayThreeElementsButNoFirstCurveCreated() {
        let subject = CanvasDrawingCurveWithPencil()

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

    /// Confirms that the creation of `actualTouchPointArray` is complete
    func testHasProcessFinished() {
        let estimatedTouchPointArray: [CanvasTouchPoint] = [
            .generate(phase: .began, estimationUpdateIndex: 0),
            .generate(phase: .moved, estimationUpdateIndex: 1),
            .generate(phase: .ended, estimationUpdateIndex: nil)
        ]
        let actualTouches: [UITouch] = [
            UITouchDummy.init(phase: .began, estimationUpdateIndex: 0),
            UITouchDummy.init(phase: .moved, estimationUpdateIndex: 1)
        ]

        let subject = CanvasPencilDrawingArrays(
            estimatedTouchPointArray: estimatedTouchPointArray
        )

        /// Confirms that `lastEstimationUpdateIndex` contains `estimationUpdateIndex` of the second-to-last element of `estimatedTouchPointArray`
        XCTAssertEqual(subject.lastEstimationUpdateIndex, 1)

        subject.appendActualTouchToActualTouchPointArray(actualTouches[0])
        XCTAssertEqual(subject.actualTouchPointArray.last?.estimationUpdateIndex, 0)

        XCTAssertFalse(subject.hasProcessFinished)

        subject.appendActualTouchToActualTouchPointArray(actualTouches[1])
        XCTAssertEqual(subject.actualTouchPointArray.last?.estimationUpdateIndex, 1)

        /// Completion is determined when `lastEstimationUpdateIndex` matches `estimationUpdateIndex` of the last element in `actualTouchPointArray`
        XCTAssertTrue(subject.hasProcessFinished)
    }

    /// Confirms that elements created by combining actual and estimated values are added to `actualTouchPointArray`
    func testAppendActualTouchWithEstimatedValue() {
        let estimatedTouches: [CanvasTouchPoint] = [
            .generate(phase: .began, force: 1.0, estimationUpdateIndex: 0),
            .generate(phase: .moved, force: 1.0, estimationUpdateIndex: 1),
            .generate(phase: .moved, force: 1.0, estimationUpdateIndex: 2),
            .generate(phase: .ended, force: 0.0, estimationUpdateIndex: nil)
        ]

        let actualTouches: [UITouch] = [
            UITouchDummy.init(phase: .began, force: 0.3, estimationUpdateIndex: 0),
            UITouchDummy.init(phase: .moved, force: 0.2, estimationUpdateIndex: 1),
            UITouchDummy.init(phase: .moved, force: 0.1, estimationUpdateIndex: 2)
        ]

        let subject = CanvasPencilDrawingArrays(
            estimatedTouchPointArray: estimatedTouches
        )

        actualTouches
            .sorted(by: { $0.timestamp < $1.timestamp })
            .forEach { value in
            subject.appendActualTouchWithEstimatedValue(value)
        }

        /// Verifie that the estimated value is used for `UITouch.Phase` and the actual value is used for `force`
        XCTAssertEqual(subject.actualTouchPointArray[0].phase, estimatedTouches[0].phase)
        XCTAssertEqual(subject.actualTouchPointArray[0].force, actualTouches[0].force)

        XCTAssertEqual(subject.actualTouchPointArray[1].phase, estimatedTouches[1].phase)
        XCTAssertEqual(subject.actualTouchPointArray[1].force, actualTouches[1].force)

        XCTAssertEqual(subject.actualTouchPointArray[2].phase, estimatedTouches[2].phase)
        XCTAssertEqual(subject.actualTouchPointArray[2].force, actualTouches[2].force)

        /// Confirm that the last element of `estimatedTouchPointArray` is added to the end of `actualTouchPointArray` at `.ended`
        XCTAssertEqual(subject.actualTouchPointArray[3].phase, estimatedTouches[3].phase)
        XCTAssertEqual(subject.actualTouchPointArray[3].force, estimatedTouches[3].force)
    }

    /// Confirms that on `.ended`, `lastEstimationUpdateIndex` matches the `estimationUpdateIndex` from the second-to-last element of `estimatedTouchPointArray`
    func testUpdateLastEstimationUpdateIndexAtTouchEnded() {
        let subject = CanvasPencilDrawingArrays()

        /// When the phase is not `.ended`, `lastEstimationUpdateIndex` will be `nil`
        subject.appendEstimatedValue(.generate(phase: .began, estimationUpdateIndex: 0))
        XCTAssertNil(subject.lastEstimationUpdateIndex)

        subject.appendEstimatedValue(.generate(phase: .moved, estimationUpdateIndex: 1))
        XCTAssertNil(subject.lastEstimationUpdateIndex)

        /// When the `phase` is `.ended`, `lastEstimationUpdateIndex` will be `estimationUpdateIndex` of the element before the last element in `estimatedTouchPointArray`
        subject.appendEstimatedValue(.generate(phase: .ended, estimationUpdateIndex: nil))
        XCTAssertEqual(subject.lastEstimationUpdateIndex, 1)
    }

    /// Confirms that on `.cancelled`, `lastEstimationUpdateIndex` contains the `estimationUpdateIndex` from the second-to-last element of `estimatedTouchPointArray`
    func testUpdateLastEstimationUpdateIndexAtTouchCancelled() {
        let subject = CanvasPencilDrawingArrays()

        /// When the phase is not `.ended`, `lastEstimationUpdateIndex` will be `nil`
        subject.appendEstimatedValue(.generate(phase: .began, estimationUpdateIndex: 0))
        XCTAssertNil(subject.lastEstimationUpdateIndex)

        subject.appendEstimatedValue(.generate(phase: .moved, estimationUpdateIndex: 1))
        XCTAssertNil(subject.lastEstimationUpdateIndex)

        /// When the `phase` is `.cancelled`, `lastEstimationUpdateIndex` will be `estimationUpdateIndex` of the element before the last element in `estimatedTouchPointArray`
        subject.appendEstimatedValue(.generate(phase: .cancelled, estimationUpdateIndex: nil))
        XCTAssertEqual(subject.lastEstimationUpdateIndex, 1)
    }

}
