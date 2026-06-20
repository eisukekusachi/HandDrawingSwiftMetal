//
//  CanvasDisplayLinkTests.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2026/01/03.
//

import Combine
import Testing

@testable import CanvasView

@MainActor
struct CanvasDisplayLinkTests {

    typealias Subject = CanvasDisplayLink

    @Test
    func `When running is enabled, the display link is unpaused`() {
        let subject = Subject(isPaused: true)

        subject.run(true)

        #expect(subject.displayLink?.isPaused == false)
    }

    @Test
    func `When running is disabled while unpaused, the display link pauses and emits once`() {
        let subject = Subject(isPaused: true)

        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(true)
        subject.run(false)

        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 1)
    }

    @Test
    func `When running is disabled while paused, the display link does not emit`() {
        let subject = Subject(isPaused: true)

        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(false)

        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 0)
    }
}
