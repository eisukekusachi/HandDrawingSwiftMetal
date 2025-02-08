//
//  CanvasFingerDrawingDictionaryTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/20.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasFingerDrawingDictionaryTests: XCTestCase {
    /// Confirms that the fingers have lifted off the screen
    func testHasFingersLiftedOffScreen() {
        struct Condition {
            let fingers: [CanvasTouchHashValue: CanvasTouchPoint]
        }
        struct Expectation {
            let result: Bool
        }

        let testCases: [(condition: Condition, expectation: Expectation)] = [
            /// Confirm that any of the touch phases are `.ended`
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .ended),
                        1: .generate(phase: .began)
                    ]
                ),
                expectation: .init(result: true)
            ),
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .began),
                        1: .generate(phase: .ended)
                    ]
                ),
                expectation: .init(result: true)
            ),
            /// Confirm that any of the touch phases are `.cancelled`
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .cancelled),
                        1: .generate(phase: .began)
                    ]
                ),
                expectation: .init(result: true)
            ),
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .began),
                        1: .generate(phase: .cancelled)
                    ]
                ),
                expectation: .init(result: true)
            ),
            /// Confirm that none of the touch phases are `.ended` or `.cancelled`
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .began),
                        1: .generate(phase: .moved)
                    ]
                ),
                expectation: .init(result: false)
            ),
        ]

        for testCase in testCases {
            let condition = testCase.condition
            let expectation = testCase.expectation

            let subject = CanvasFingerDrawingDictionary()
            subject.appendTouches(condition.fingers)

            XCTAssertEqual(subject.hasFingerLiftedOffScreen, expectation.result)
        }
    }

    /// Confirms that the latest actual touch points are returned from `touchArrayDictionary`
    func testGetLatestTouchPoints() {
        let key: CanvasTouchHashValue = 0
        let subject = CanvasFingerDrawingDictionary()

        let touchPoints: [CanvasTouchPoint] = [
            .generate(phase: .began, estimationUpdateIndex: 0),
            .generate(phase: .moved, estimationUpdateIndex: 1),
            .generate(phase: .moved, estimationUpdateIndex: 2),
            .generate(phase: .moved, estimationUpdateIndex: 3)
        ]

        /// Confirm that it is empty at the start
        XCTAssertEqual(subject.getLatestTouchPoints(for: key), nil)
        XCTAssertEqual(subject.latestTouchPoint, nil)

        /// Add two elements to `touchArrayDictionary`
        subject.appendTouches([key: touchPoints[0]])
        subject.appendTouches([key: touchPoints[1]])

        /// When `getLatestTouchPoints` is called, two elements are returned.
        /// At that point, `CanvasTouchPoint` of the last element in `touchArrayDictionary` is stored in `latestTouchPoint`.
        XCTAssertEqual(subject.getLatestTouchPoints(for: key)!, [touchPoints[0], touchPoints[1]])
        XCTAssertEqual(subject.latestTouchPoint, touchPoints[1])

        /// Add  two more elements to `touchArrayDictionary`
        subject.appendTouches([key: touchPoints[2]])
        subject.appendTouches([key: touchPoints[3]])

        /// Confirm that values after `latestTouchPoint` are obtained from `getLatestTouchPoints`
        XCTAssertEqual(subject.getLatestTouchPoints(for: key)!, [touchPoints[2], touchPoints[3]])
        XCTAssertEqual(subject.latestTouchPoint, touchPoints[3])
    }

    func testRemoveIfLastElementMatches() {
        let key0: CanvasTouchHashValue = 0
        let key1: CanvasTouchHashValue = 1

        let subject = CanvasFingerDrawingDictionary(
            touchArrayDictionary: [
                key0: [
                    .generate(phase: .began, estimationUpdateIndex: 0)
                ],
                key1: [
                    .generate(phase: .began, estimationUpdateIndex: 0)
                ]
            ]
        )

        /// Nothing is removed because the last element is neither `.ended` nor `.cancelled`
        subject.removeIfLastElementMatches(phases: [.ended, .cancelled])
        XCTAssertEqual(subject.touchArrayDictionary.count, 2)

        /// The element with the last `.ended` phase is removed
        subject.appendTouches([key0: .generate(phase: .ended, estimationUpdateIndex: 1)])
        subject.removeIfLastElementMatches(phases: [.ended, .cancelled])
        XCTAssertEqual(subject.touchArrayDictionary.count, 1)

        /// The element with the last `.cancelled` phase is removed
        subject.appendTouches([key1: .generate(phase: .cancelled, estimationUpdateIndex: 1)])
        subject.removeIfLastElementMatches(phases: [.ended, .cancelled])
        XCTAssertEqual(subject.touchArrayDictionary.count, 0)
    }

}
