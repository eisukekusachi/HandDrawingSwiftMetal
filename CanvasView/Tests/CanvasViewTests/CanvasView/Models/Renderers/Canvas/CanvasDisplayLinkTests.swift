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
    func `When the stroke is drawing, the display link is unpaused`() {
        let subject = Subject(isPaused: true)

        subject.run(.drawing)

        #expect(subject.displayLink?.isPaused == false)
    }

    @Test
    func `When the stroke is finalizing, the display link pauses without emitting`() {
        let subject = Subject(isPaused: true)

        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(.drawing)
        subject.run(.finalizing(cancelled: false))

        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 0)
    }

    @Test
    func `When the stroke is finalizing while paused, the display link does not emit`() {
        let subject = Subject(isPaused: true)

        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(.finalizing(cancelled: false))

        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 0)
    }

    @Test
    func `When the stroke returns to idle while unpaused, the display link pauses and emits one final update`() {
        let subject = Subject(isPaused: true)

        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(.drawing)
        subject.run(.idle)

        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 1)
    }

    @Test
    func `When the stroke returns to idle while paused, the display link does not emit`() {
        let subject = Subject(isPaused: true)

        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(.idle)

        #expect(subject.displayLink?.isPaused == true)
        #expect(emitCount == 0)
    }
}
