//
//  TransformLifecycleManagerTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/07.
//

import Testing

@testable import CanvasView

@MainActor
struct TransformLifecycleManagerTests {

    private typealias Subject = TransformLifecycleManager

    @Test
    func `beginIfIdle transitions idle to transforming`() {
        let subject = Subject()

        #expect(subject.beginIfIdle())
        #expect(subject.phase == .transforming)
    }

    @Test
    func `beginIfIdle returns false when not idle`() {
        let subject = Subject()

        subject.beginIfIdle()
        #expect(subject.beginIfIdle() == false)
        #expect(subject.phase == .transforming)
    }

    @Test
    func `finalizeIfTransforming transitions transforming to finalizing`() {
        let subject = Subject()

        subject.beginIfIdle()
        subject.finalizeIfTransforming()

        #expect(subject.phase == .finalizing)
    }

    @Test
    func `complete transitions finalizing to idle`() {
        let subject = Subject()

        subject.beginIfIdle()
        subject.finalizeIfTransforming()
        subject.complete()

        #expect(subject.phase == .idle)
    }

    @Test
    func `complete is a no-op when not finalizing`() {
        let subject = Subject()

        subject.beginIfIdle()
        subject.complete()

        #expect(subject.phase == .transforming)
    }

    @Test
    func `reset always transitions to idle`() {
        let subject = Subject()

        subject.beginIfIdle()
        subject.finalizeIfTransforming()
        subject.reset()

        #expect(subject.phase == .idle)
    }
}
