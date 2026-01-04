//
//  DrawingDisplayLinkTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/01/03.
//

import Combine
import UIKit
import Testing

@testable import CanvasView

@MainActor
struct DrawingDisplayLinkTests {

    typealias Subject = DrawingDisplayLink

    @Test
    func `When run(true) is called while the display link is paused, it starts running`() async throws {
        let subject = Subject(isPaused: true)

        // When a value flows through the publisher, the canvas is updated
        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(true)

        // The display link runs and the screen continues to update
        #expect(await TestHelpers.waitUntil { emitCount >= 1 })
        let countAfterFirst = emitCount
        #expect(await TestHelpers.waitUntil { emitCount >= countAfterFirst + 1 })

        // The display link continues running
        #expect(subject.displayLink?.isPaused == false)
    }

    @Test
    func `When run(false) is called while the display link is running, it stops after updating once`() async throws {
        let subject = Subject(isPaused: false)

        // When a value flows through the publisher, the canvas is updated
        var emitCount = 0
        let cancellable = subject.update.sink { _ in emitCount += 1 }
        defer { cancellable.cancel() }

        subject.run(false)

        // After the display link stops, the screen is updated once and is not updated afterward
        #expect(await TestHelpers.waitUntil { emitCount >= 1 })
        let countAfterFirst = emitCount
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(emitCount == countAfterFirst)

        // The display link stops
        #expect(subject.displayLink?.isPaused == true)
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
