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
                expectation: .init(
                    result: true
                )
            ),
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .began),
                        1: .generate(phase: .ended)
                    ]
                ),
                expectation: .init(
                    result: true
                )
            ),
            /// Confirm that any of the touch phases are `.cancelled`
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .cancelled),
                        1: .generate(phase: .began)
                    ]
                ),
                expectation: .init(
                    result: true
                )
            ),
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .began),
                        1: .generate(phase: .cancelled)
                    ]
                ),
                expectation: .init(
                    result: true
                )
            ),
            /// Confirm that none of the touch phases are `.ended` or `.cancelled`
            (
                condition: .init(
                    fingers: [
                        0: .generate(phase: .began),
                        1: .generate(phase: .moved)
                    ]
                ),
                expectation: .init(
                    result: false
                )
            ),
        ]

        for testCase in testCases {
            let condition = testCase.condition
            let expectation = testCase.expectation

            let subject = CanvasFingerDrawingDictionary()
            subject.appendTouches(condition.fingers)

            XCTAssertEqual(subject.hasFingersLiftedOffScreen, expectation.result)
        }
    }

}
