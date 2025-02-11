//
//  CanvasFingerScreenTouchesTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/09.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasFingerScreenTouchesTests: XCTestCase {
    /// Confirms finger input
    func testLatestTouchPoints() {
        let subject = CanvasFingerScreenTouches(
            touchArrayDictionary:[
                1: [
                    .generate(location: .init(x: 0, y: 0), phase: .began),
                    .generate(location: .init(x: 1, y: 1), phase: .moved)
                ],
                0: [
                    .generate(location: .init(x: 0, y: 0), phase: .began)
                ]
            ]
        )

        // If no active key is set, nothing is returned.
        XCTAssertEqual(subject.latestTouchPoints, [])

        // When `activeDictionaryKey` is set, the values with `activeDictionaryKey` are returned.
        subject.updateActiveDictionaryKeyIfKeyIsNil()
        XCTAssertEqual(subject.activeDictionaryKey, 0)
        XCTAssertEqual(
            subject.latestTouchPoints.map { $0.location },
            [
                .init(x: 0, y: 0)
            ]
        )

        // After `latestTouchPoints` is called once, it returns empty.
        XCTAssertEqual(subject.latestTouchPoints, [])

        // Add new values
        subject.appendTouchPointToDictionary([0: .generate(location: .init(x: 1, y: 1), phase: .moved)])
        subject.appendTouchPointToDictionary([0: .generate(location: .init(x: 2, y: 2), phase: .ended)])

        XCTAssertEqual(
            subject.latestTouchPoints.map { $0.location },
            [
                .init(x: 1, y: 1),
                .init(x: 2, y: 2)
            ]
        )

        // If the phase is ended, the element is removed from the dictionary
        subject.removeEndedTouchArrayFromDictionary()
        XCTAssertFalse(subject.touchArrayDictionary.keys.contains(0))
        XCTAssertTrue(subject.touchArrayDictionary.keys.contains(1))
    }

    /// Confirms that all fingers are on the screen
    func testIsAllFingersOnScreen() {
        struct Condition {
            let fingers: [CanvasTouchHashValue: [CanvasTouchPoint]]
        }
        struct Expectation {
            let result: Bool
        }

        let testCases: [(condition: Condition, expectation: Expectation)] = [
            (
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began)
                        ],
                        1: [
                            .generate(phase: .began)
                        ]
                    ]
                ),
                expectation: .init(result: true)
            ),
            (
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ],
                        1: [
                            .generate(phase: .began)
                        ]
                    ]
                ),
                expectation: .init(result: true)
            ),
            (
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ],
                        1: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ]
                    ]
                ),
                expectation: .init(result: true)
            ),
            (
                // When the last element of the dictionary array is ‘ended’, it will be false.
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began),
                            .generate(phase: .moved),
                            .generate(phase: .ended)
                        ],
                        1: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ]
                    ]
                ),
                expectation: .init(result: false)
            ),
            (
                // When the last element of the dictionary array is ‘cancelled’, it will be false.
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began),
                            .generate(phase: .moved),
                            .generate(phase: .cancelled)
                        ],
                        1: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ]
                    ]
                ),
                expectation: .init(result: false)
            ),
            (
                // This case does not occur, but if the last element of the dictionary array is not ‘cancelled’, it will be true.
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began),
                            .generate(phase: .moved),
                            .generate(phase: .cancelled),
                            .generate(phase: .moved),
                        ],
                        1: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ]
                    ]
                ),
                expectation: .init(result: true)
            ),
            (
                // This case does not occur, but if the last element of the dictionary array is not ‘ended’, it will be true.
                condition: .init(
                    fingers: [
                        0: [
                            .generate(phase: .began),
                            .generate(phase: .moved),
                            .generate(phase: .ended),
                            .generate(phase: .moved),
                        ],
                        1: [
                            .generate(phase: .began),
                            .generate(phase: .moved)
                        ]
                    ]
                ),
                expectation: .init(result: true)
            )
        ]

        testCases.forEach { testCase in
            let condition = testCase.condition
            let expectation = testCase.expectation

            let subject = CanvasFingerScreenTouches(
                touchArrayDictionary: condition.fingers
            )

            XCTAssertEqual(subject.isAllFingersOnScreen, expectation.result)
        }
    }

    func testUpdateDictionaryKeyIfKeyIsNil() {
        let dictionary: [CanvasTouchHashValue: [CanvasTouchPoint]] =
        [
            2: [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 1, y: 1)),
                .generate(location: .init(x: 2, y: 2))
            ],
            0: [
                .generate(location: .init(x: 0, y: 0))
            ],
            1: [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 1, y: 1))
            ]
        ]

        let subject = CanvasFingerScreenTouches(touchArrayDictionary: dictionary)

        subject.updateActiveDictionaryKeyIfKeyIsNil()

        // After sorting by key, the first element is set as `activeDictionaryKey`
        XCTAssertEqual(subject.activeDictionaryKey, 0)
    }

    func testReset() {
        let subject = CanvasFingerScreenTouches(
            touchArrayDictionary: [
                1: [
                    .generate(location: .init(x: 0, y: 0)),
                    .generate(location: .init(x: 1, y: 1))
                ],
                0: [
                    .generate(location: .init(x: 0, y: 0))
                ]
            ],
            activeDictionaryKey: 0,
            activeLatestTouchPoint: .generate(location: .init(x: 0, y: 0))
        )

        XCTAssertFalse(subject.touchArrayDictionary.isEmpty)
        XCTAssertNotNil(subject.activeDictionaryKey)
        XCTAssertNotNil(subject.activeLatestTouchPoint)

        subject.reset()

        XCTAssertTrue(subject.touchArrayDictionary.isEmpty)
        XCTAssertNil(subject.activeDictionaryKey)
        XCTAssertNil(subject.activeLatestTouchPoint)

    }

}
