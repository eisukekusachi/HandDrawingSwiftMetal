//
//  CanvasDisplayLinkTests.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2026/01/03.
//

import Combine
import UIKit
import Testing

@testable import CanvasView

@MainActor
struct CanvasDisplayLinkTests {

    typealias Subject = CanvasDisplayLink

    @Test(
        arguments: [
            UITouch.Phase.began,
            UITouch.Phase.moved,
            UITouch.Phase.stationary
        ]
    )
    func `When the finger is touching the screen, the display link is unpaused`(phase: UITouch.Phase) {
        let subject = Subject(isPaused: true)

        subject.run(phase)

        #expect(subject.displayLink?.isPaused == false)
    }

    @Test(
        arguments: [
            UITouch.Phase.ended,
            UITouch.Phase.cancelled,
            UITouch.Phase.regionEntered,
            UITouch.Phase.regionMoved,
            UITouch.Phase.regionExited
        ]
    )
    func `When the finger is lifted from the screen, the display link pauses and emits one final update`(phase: UITouch.Phase) {
        let subject = Subject(isPaused: true)

        // When a value flows through the publisher, the canvas is updated
        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(.moved)
        #expect(subject.displayLink?.isPaused == false)

        subject.run(phase)

        // The display link stops
        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 1)
    }
}
