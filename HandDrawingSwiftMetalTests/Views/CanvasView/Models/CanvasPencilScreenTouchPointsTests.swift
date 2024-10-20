//
//  CanvasPencilScreenTouchPointsTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasPencilScreenTouchPointsTests: XCTestCase {

    /// Confirms that the replacement with the actual values is complete
    func testHasActualValueReplacementCompleted() {
        let estimatedTouchPointArray: [CanvasTouchPoint] = [
            .generate(phase: .began, estimationUpdateIndex: 0),
            .generate(phase: .moved, estimationUpdateIndex: 1),
            .generate(phase: .ended, estimationUpdateIndex: nil)
        ]
        let actualTouches: [UITouch] = [
            UITouchDummy.init(phase: .began, estimationUpdateIndex: 0),
            UITouchDummy.init(phase: .moved, estimationUpdateIndex: 1)
        ]

        let subject = CanvasPencilScreenTouchPoints(
            estimatedTouchPointArray: estimatedTouchPointArray
        )
        subject.updateLastEstimationUpdateIndexAtCompletionForTouchCompletion()

        /// Confirms that `lastEstimationUpdateIndexAtCompletion` contains `estimationUpdateIndex` of the second-to-last element of `estimatedTouchPointArray`
        XCTAssertEqual(subject.lastEstimationUpdateIndexAtCompletion, 1)

        subject.appendActualValueWithEstimatedValue(actualTouches[0])
        XCTAssertEqual(subject.actualTouchPointArray.last?.estimationUpdateIndex, 0)

        XCTAssertFalse(subject.hasActualValueReplacementCompleted)

        subject.appendActualValueWithEstimatedValue(actualTouches[1])
        XCTAssertEqual(subject.actualTouchPointArray.last?.estimationUpdateIndex, 1)

        /// Completion is determined when `lastEstimationUpdateIndexAtCompletion` matches `estimationUpdateIndex` of the last element in `actualTouchPointArray`
        XCTAssertTrue(subject.hasActualValueReplacementCompleted)
    }

    /// Confirms that elements created by combining actual and estimated values are added to `actualTouchPointArray`
    func testAppendActualValueWithEstimatedValue() {
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

        let subject = CanvasPencilScreenTouchPoints(
            estimatedTouchPointArray: estimatedTouches
        )
        subject.updateLastEstimationUpdateIndexAtCompletionForTouchCompletion()

        actualTouches
            .sorted(by: { $0.timestamp < $1.timestamp })
            .forEach { value in
            subject.appendActualValueWithEstimatedValue(value)
        }

        /// Replacement is complete if the last `estimationUpdateIndex` in `actualTouchPointArray` matches `lastEstimationUpdateIndexAtCompletion`
        if subject.hasActualValueReplacementCompleted {
            /// Since `.ended` event is not sent from the Apple Pencil,
            /// the last element of `estimatedTouchPointArray` is added to the end of `actualTouchPointArray` to finalize the process
            subject.appendLastEstimatedTouchPointToActualTouchPointArray()
        }

        /// Verifies that the estimated value is used for `UITouch.Phase` and the actual value is used for `force`
        XCTAssertEqual(subject.actualTouchPointArray[0].phase, estimatedTouches[0].phase)
        XCTAssertEqual(subject.actualTouchPointArray[0].force, actualTouches[0].force)

        XCTAssertEqual(subject.actualTouchPointArray[1].phase, estimatedTouches[1].phase)
        XCTAssertEqual(subject.actualTouchPointArray[1].force, actualTouches[1].force)

        XCTAssertEqual(subject.actualTouchPointArray[2].phase, estimatedTouches[2].phase)
        XCTAssertEqual(subject.actualTouchPointArray[2].force, actualTouches[2].force)

        /// Confirms that the last element of `estimatedTouchPointArray` is added to the end of `actualTouchPointArray` at `.ended`
        XCTAssertEqual(subject.actualTouchPointArray[3].phase, estimatedTouches[3].phase)
        XCTAssertEqual(subject.actualTouchPointArray[3].force, estimatedTouches[3].force)
    }

    /// Confirms that on `.ended`, `lastEstimationUpdateIndexAtCompletion` contains the `estimationUpdateIndex` from the second-to-last element of `estimatedTouchPointArray`
    func testUpdateLastEstimationUpdateIndexAtTouchEnded() {
        let subject = CanvasPencilScreenTouchPoints()

        /// When the phase is not `.ended`, `lastEstimationUpdateIndexAtCompletion` will be `nil`
        subject.appendEstimatedValue(.generate(phase: .began, estimationUpdateIndex: 0))
        XCTAssertNil(subject.lastEstimationUpdateIndexAtCompletion)

        subject.appendEstimatedValue(.generate(phase: .moved, estimationUpdateIndex: 1))
        XCTAssertNil(subject.lastEstimationUpdateIndexAtCompletion)

        subject.appendEstimatedValue(.generate(phase: .moved, estimationUpdateIndex: 2))
        XCTAssertNil(subject.lastEstimationUpdateIndexAtCompletion)

        /// When the `phase` is `.ended`, `lastEstimationUpdateIndexAtCompletion` will be `estimationUpdateIndex` of the element before the last element in `estimatedTouchPointArray`
        subject.appendEstimatedValue(.generate(phase: .ended, estimationUpdateIndex: nil))
        XCTAssertEqual(subject.lastEstimationUpdateIndexAtCompletion, 2)
    }

    /// Confirms that on `.cancelled`, `lastEstimationUpdateIndexAtCompletion` contains the `estimationUpdateIndex` from the second-to-last element of `estimatedTouchPointArray`
    func testUpdateLastEstimationUpdateIndexAtTouchCancelled() {
        let subject = CanvasPencilScreenTouchPoints()

        /// When the phase is not `.ended`, `lastEstimationUpdateIndexAtCompletion` will be `nil`
        subject.appendEstimatedValue(.generate(phase: .began, estimationUpdateIndex: 0))
        XCTAssertNil(subject.lastEstimationUpdateIndexAtCompletion)

        subject.appendEstimatedValue(.generate(phase: .moved, estimationUpdateIndex: 1))
        XCTAssertNil(subject.lastEstimationUpdateIndexAtCompletion)

        subject.appendEstimatedValue(.generate(phase: .moved, estimationUpdateIndex: 2))
        XCTAssertNil(subject.lastEstimationUpdateIndexAtCompletion)

        /// When the `phase` is `.cancelled`, `lastEstimationUpdateIndexAtCompletion` will be `estimationUpdateIndex` of the element before the last element in `estimatedTouchPointArray`
        subject.appendEstimatedValue(.generate(phase: .cancelled, estimationUpdateIndex: nil))
        XCTAssertEqual(subject.lastEstimationUpdateIndexAtCompletion, 2)
    }

}
