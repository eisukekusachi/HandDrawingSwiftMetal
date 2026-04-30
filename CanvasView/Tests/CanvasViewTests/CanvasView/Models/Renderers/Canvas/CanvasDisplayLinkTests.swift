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

    @Test
    func `When the finger is touching the screen, the display link is unpaused`() {
        let phases: [UITouch.Phase] = [.began, .moved, .stationary]

        for touchPhase in phases {
            let subject = Subject(isPaused: true)

            subject.run(touchPhase)

            #expect(subject.displayLink?.isPaused == false)
            subject.stop()
        }
    }

    @Test
    func `When the finger is lifted from the screen, the display link pauses and emits one final update`() {
        let phases: [UITouch.Phase] = [.ended, .cancelled, .regionEntered, .regionMoved, .regionExited]

        for touchPhase in phases {
            let subject = Subject(isPaused: true)

            // When a value flows through the publisher, the canvas is updated
            var emitCount = 0
            let cancellable = subject.update.sink { _ in emitCount += 1 }
            defer { cancellable.cancel() }

            subject.run(.moved)
            #expect(subject.displayLink?.isPaused == false)

            subject.run(touchPhase)

            // The display link stops
            #expect(subject.displayLink?.isPaused == true)
            #expect(emitCount == 1)
        }
    }

    @Test
    func `When stop() is called while the display link is running, it stops without emitting updates`() async throws {
        let subject = Subject(isPaused: false)

        // When a value flows through the publisher, the canvas is updated
        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.stop()

        // No value flows through the publisher
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(emitCount == 0)

        // The display link stops
        #expect(subject.displayLink?.isPaused == true)
    }
}
