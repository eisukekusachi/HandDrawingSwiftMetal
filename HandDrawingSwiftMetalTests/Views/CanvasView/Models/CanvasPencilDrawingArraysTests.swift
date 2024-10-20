//
//  CanvasPencilDrawingArraysTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/20.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasPencilDrawingArraysTests: XCTestCase {
    /// Confirms that the creation of `actualTouchPointArray` is complete
    func testHasProcessFinished() {
        let actualTouches: [UITouch] = [
            UITouchDummy.init(phase: .began, estimationUpdateIndex: 0),
            UITouchDummy.init(phase: .moved, estimationUpdateIndex: 1)
        ]

        let subject = CanvasPencilDrawingArrays(
            estimatedTouchPointArray: [
                .generate(phase: .began, estimationUpdateIndex: 0),
                .generate(phase: .moved, estimationUpdateIndex: 1),
                .generate(phase: .ended, estimationUpdateIndex: nil)
            ]
        )

        /// `estimationUpdateIndex` of the last element in `estimatedTouchPointArray` is nil,
        /// so `lastEstimationUpdateIndex` contains `estimationUpdateIndex` of the second-to-last element in `estimatedTouchPointArray`
        XCTAssertEqual(subject.lastEstimationUpdateIndex, 1)

        subject.appendActualTouchToActualTouchPointArray(actualTouches[0])
        XCTAssertEqual(subject.actualTouchPointArray.last?.estimationUpdateIndex, 0)

        /// Completion is not determined when `estimationUpdateIndex` of the last element in `actualTouchPointArray` does not match `lastEstimationUpdateIndex`
        XCTAssertFalse(subject.hasProcessFinished)

        subject.appendActualTouchToActualTouchPointArray(actualTouches[1])
        XCTAssertEqual(subject.actualTouchPointArray.last?.estimationUpdateIndex, 1)

        /// Completion is determined when `estimationUpdateIndex` of the last element in `actualTouchPointArray` matches `lastEstimationUpdateIndex`
        XCTAssertTrue(subject.hasProcessFinished)
    }

    func testHasPencilLiftedOffScreen() {
        let subject = CanvasPencilDrawingArrays()
        XCTAssertFalse(subject.hasPencilLiftedOffScreen(.began))
        XCTAssertFalse(subject.hasPencilLiftedOffScreen(.moved))
        XCTAssertTrue(subject.hasPencilLiftedOffScreen(.ended))
        XCTAssertTrue(subject.hasPencilLiftedOffScreen(.cancelled))
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

        /// Verify that the estimated value is used for `UITouch.Phase` and the actual value is used for `force`
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

    /// Confirms that the latest actual touch points are returned from `actualTouchPointArray`
    func testGetLatestActualTouchPoints() {
        let conditions: [UITouch] = [
            UITouchDummy.init(estimationUpdateIndex: 0),
            UITouchDummy.init(estimationUpdateIndex: 1),
            UITouchDummy.init(estimationUpdateIndex: 2),
            UITouchDummy.init(estimationUpdateIndex: 3)
        ]

        let expectations: [CanvasTouchPoint] = [
            .generate(estimationUpdateIndex: 0),
            .generate(estimationUpdateIndex: 1),
            .generate(estimationUpdateIndex: 2),
            .generate(estimationUpdateIndex: 3)
        ]

        let subject = CanvasPencilDrawingArrays(
            estimatedTouchPointArray: [
                .generate(phase: .began, estimationUpdateIndex: 0),
                .generate(phase: .moved, estimationUpdateIndex: 1),
                .generate(phase: .moved, estimationUpdateIndex: 2),
                .generate(phase: .moved, estimationUpdateIndex: 3)
            ]
        )

        /// Confirm that it is empty at the start
        XCTAssertEqual(subject.getLatestActualTouchPoints(), [])
        XCTAssertEqual(subject.latestActualTouchPoint, nil)

        /// Add two elements to `actualTouchPointArray`
        subject.appendActualTouchToActualTouchPointArray(conditions[0])
        subject.appendActualTouchToActualTouchPointArray(conditions[1])

        /// When `getLatestActualTouchPoints` is called, two elements are returned.
        /// At that point, `CanvasTouchPoint` of the last element in `actualTouchPointArray` is stored in `latestActualTouchPoint`.
        let resultsA = subject.getLatestActualTouchPoints()
        XCTAssertEqual(
            [resultsA[0].estimationUpdateIndex, resultsA[1].estimationUpdateIndex],
            [expectations[0].estimationUpdateIndex, expectations[1].estimationUpdateIndex]
        )
        XCTAssertEqual(subject.latestActualTouchPoint?.estimationUpdateIndex, expectations[1].estimationUpdateIndex)

        /// Add two more elements to `actualTouchPointArray`
        subject.appendActualTouchToActualTouchPointArray(conditions[2])
        subject.appendActualTouchToActualTouchPointArray(conditions[3])

        /// Although the total number of elements in `actualTouchPointArray` is 4,
        /// when `getLatestActualTouchPoints` is called, the two elements after `latestActualTouchPoint` are returned
        let resultsB = subject.getLatestActualTouchPoints()
        XCTAssertEqual(
            [resultsB[0].estimationUpdateIndex, resultsB[1].estimationUpdateIndex],
            [expectations[2].estimationUpdateIndex, expectations[3].estimationUpdateIndex]
        )
        XCTAssertEqual(subject.latestActualTouchPoint?.estimationUpdateIndex, expectations[3].estimationUpdateIndex)
    }

}
