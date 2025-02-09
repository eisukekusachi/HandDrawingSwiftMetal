//
//  CanvasFingerScreenTouchesTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/09.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasFingerScreenTouchesTests: XCTestCase {

    /// Confirms the process of adding and removing values in `touchArrayDictionary`
    func testTouchArrayLifecycleInDictionary() {
        let dictionary: [CanvasTouchHashValue: [CanvasTouchPoint]] =
        [
            1: [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 1, y: 1))
            ],
            0: [
                .generate(location: .init(x: 0, y: 0))
            ]
        ]

        let subject = CanvasFingerScreenTouches(touchArrayDictionary: dictionary)

        // If no active key is set, nothing is returned.
        XCTAssertEqual(subject.latestTouchPoints, [])

        // When `activeDictionaryKey` is set, the values with `activeDictionaryKey` are returned.
        subject.updateActiveDictionaryKeyIfKeyIsNil()
        XCTAssertEqual(subject.activeDictionaryKey, 0)
        XCTAssertEqual(subject.latestTouchPoints, [
            .generate(location: .init(x: 0, y: 0))
        ])

        // If there is no latest value, nothing is returned.
        XCTAssertEqual(subject.latestTouchPoints, [])

        // When new values are added to the array, only the new values are retrieved.
        subject.appendTouchPointToDictionary([0: .generate(location: .init(x: 1, y: 1))])
        subject.appendTouchPointToDictionary([0: .generate(location: .init(x: 2, y: 2))])
        XCTAssertEqual(subject.latestTouchPoints, [
            .generate(location: .init(x: 1, y: 1)),
            .generate(location: .init(x: 2, y: 2))
        ])

        // If values are added with a key other than `activeDictionaryKey`, nothing is returned.
        subject.appendTouchPointToDictionary([1: .generate(location: .init(x: 2, y: 2))])
        subject.appendTouchPointToDictionary([1: .generate(location: .init(x: 3, y: 3))])
        XCTAssertEqual(subject.latestTouchPoints, [])

        // When `removeEndedTouchArrayFromDictionary` is called,
        // if the array contains ended or cancelled, the array will be removed from the dictionary.
        subject.appendTouchPointToDictionary([0: .generate(location: .init(x: 3, y: 3), phase: .ended)])
        subject.removeEndedTouchArrayFromDictionary()
        XCTAssertEqual(subject.latestTouchPoints, [])
    }

}

extension CanvasFingerScreenTouchesTests {

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

    func testIsFingersOnScreen() {
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

            XCTAssertEqual(subject.isFingersOnScreen, expectation.result)
        }
    }

    func testReset() {
        let dictionary: [CanvasTouchHashValue: [CanvasTouchPoint]] =
        [
            1: [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 1, y: 1))
            ],
            0: [
                .generate(location: .init(x: 0, y: 0))
            ]
        ]

        let subject = CanvasFingerScreenTouches(touchArrayDictionary: dictionary)

        XCTAssertEqual(subject.touchArrayDictionary, dictionary)

        subject.reset()

        XCTAssertEqual(subject.touchArrayDictionary, [:])
    }

}
