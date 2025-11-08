//
//  TouchGestureStateTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import Testing

@testable import CanvasView

struct TouchGestureStateTests {

    private typealias Subject = TouchGestureState

    func `Verifies that the initial state is .undetermined`() {
        let subject = Subject()

        #expect(subject.state == .undetermined)
    }

    @Test(
        arguments: [
            // Single-finger input, but the input duration has not reached drawingGestureRecognitionSecond
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.09)
                ]
            ],
            // Two-finger input, but the input duration for both fingers has not reached transformingGestureRecognitionSecond
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.09)
                ],
                1: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ]
            ],
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ],
                1: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.09)
                ]
            ],
            // Three-finger input
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ],
                1: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ],
                2: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ]
            ]
        ]
    )
    func `Verifies that the state is still undetermined even when finger input is detected`(histories: TouchHistoriesOnScreen) {
        let subject = Subject(
            drawingGestureRecognitionSecond: 0.1,
            transformingGestureRecognitionSecond: 0.1
        )

        subject.update(histories)

        #expect(subject.state == .undetermined)
    }

    @Test(
        arguments: [
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ]
            ],
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.5),
                    TouchPoint.generate(timestamp: 0.1)
                ]
            ]
        ]
    )
    func `Verifies that the state becomes .drawing`(histories: TouchHistoriesOnScreen) {
        let subject = Subject(
            drawingGestureRecognitionSecond: 0.1
        )

        subject.update(histories)

        #expect(subject.state == .drawing)
    }

    @Test(
        arguments: [
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ],
                1: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ],
            ],
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.5),
                    TouchPoint.generate(timestamp: 0.1)
                ],
                1: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.5),
                    TouchPoint.generate(timestamp: 0.1)
                ]
            ]
        ]
    )
    func `Verifies that the state becomes .transforming`(histories: TouchHistoriesOnScreen) {
        let subject = Subject(
            transformingGestureRecognitionSecond: 0.1
        )

        subject.update(histories)

        #expect(subject.state == .transforming)
    }
}
