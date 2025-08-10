//
//  TouchGestureStateTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import Testing

@testable import CanvasView

@Suite("TouchGestureState Tests")
struct TouchGestureStateTests {

    @Test("Confirms that the initial state is .undetermined")
    func initialState() {
        let subject = TouchGestureState()
        #expect(subject.state == .undetermined)
    }

    @Test(
        "Confirms that the state is still undetermined even when finger input is detected",
        arguments: [
            // Single-finger input, but the input duration has not reached drawingGestureRecognitionSecond
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.09)]
            ],
            // Two-finger input, but the input duration for both fingers has not reached transformingGestureRecognitionSecond
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.09)],
                1: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)]
            ],
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)],
                1: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.09)]
            ],
            // Three-finger input
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)],
                1: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)],
                2: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)]
            ]
        ]
    )
    func initialStateIsStillUndetermined(histories: TouchHistoriesOnScreen) {
        let subject = TouchGestureState(
            drawingGestureRecognitionSecond: 0.1,
            transformingGestureRecognitionSecond: 0.1
        )
        subject.update(histories)
        #expect(subject.state == .undetermined)
    }

    @Test(
        "Confirms that the status becomes .drawing",
        arguments: [
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)]
            ],
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.5), TouchPoint.generate(timestamp: 0.1)]
            ]
        ]
    )
    func stateIsDrawing(histories: TouchHistoriesOnScreen) {
        let subject = TouchGestureState(
            drawingGestureRecognitionSecond: 0.1
        )
        subject.update(histories)
        #expect(subject.state == .drawing)
    }

    @Test(
        "Confirm that the status becomes .transforming",
        arguments: [
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)],
                1: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.1)],
            ],
            [
                0: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.5), TouchPoint.generate(timestamp: 0.1)],
                1: [TouchPoint.generate(timestamp: 0), TouchPoint.generate(timestamp: 0.5), TouchPoint.generate(timestamp: 0.1)]
            ]
        ]
    )
    func stateIsTransforming(histories: TouchHistoriesOnScreen) {
        let subject = TouchGestureState(
            transformingGestureRecognitionSecond: 0.1
        )
        subject.update(histories)
        #expect(subject.state == .transforming)
    }
}
