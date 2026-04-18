//
//  TouchGestureStateTests.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import Testing

@testable import CanvasView

@MainActor
struct TouchGestureStateTests {

    private typealias Subject = TouchGestureState

    @Test
    func `Verifies that the initial state is .undetermined`() {
        let subject = Subject()

        #expect(subject.state == .undetermined)
    }
/*
    @Test
    func `Verifies that the state is still undetermined even when finger input is detected`() {
        let cases: [[Int: [TouchPoint]]] = [
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

        let subject = Subject(
            drawingGestureRecognitionSecond: 0.1,
            transformingGestureRecognitionSecond: 0.1
        )

        for caseHistories in cases {
            subject.update(TestHelpers.makeTouchHistories(caseHistories))
            #expect(subject.state == .undetermined)
            subject.reset()
        }
    }
*/
/*
    @Test
    func `Verifies that the state becomes .drawing`() {
        let cases: [[Int: [TouchPoint]]] = [
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

        let subject = Subject(
            drawingGestureRecognitionSecond: 0.1
        )

        for caseHistories in cases {
            subject.update(TestHelpers.makeTouchHistories(caseHistories))
            #expect(subject.state == .drawing)
            subject.reset()
        }
    }
*/
/*
    @Test
    func `Verifies that the state becomes .transforming`() {
        let cases: [[Int: [TouchPoint]]] = [
            [
                0: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ],
                1: [
                    TouchPoint.generate(timestamp: 0),
                    TouchPoint.generate(timestamp: 0.1)
                ]
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

        let subject = Subject(
            transformingGestureRecognitionSecond: 0.1
        )

        for caseHistories in cases {
            subject.update(TestHelpers.makeTouchHistories(caseHistories))
            #expect(subject.state == .transforming)
            subject.reset()
        }
    }
*/
}
