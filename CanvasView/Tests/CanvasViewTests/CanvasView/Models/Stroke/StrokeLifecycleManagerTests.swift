//
//  StrokeLifecycleManagerTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/15.
//

import Testing

@testable import CanvasView

@MainActor
struct StrokeLifecycleManagerTests {

    private typealias Subject = StrokeLifecycleManager

    @MainActor
    @Suite
    struct `Normal cases` {
        @Test
        func `Verify that beginIfIdle transitions from idle to drawing`() {
            let subject = Subject()

            subject.beginIfIdle()

            #expect(subject.phase == .drawing)
        }

        @Test
        func `Verify that finalizeIfDrawing transitions from drawing to finalizing`() {
            let subject = Subject()

            subject.beginIfIdle()
            subject.finalizeIfDrawing()

            #expect(subject.phase == .finalizing(cancelled: false))
        }

        @Test
        func `Verify that finalizeIfDrawing transitions from drawing to finalizing when cancelled`() {
            let subject = Subject()

            subject.beginIfIdle()
            subject.finalizeIfDrawing(cancelled: true)

            #expect(subject.phase == .finalizing(cancelled: true))
        }

        @Test
        func `Verify that complete transitions from finalizing to idle`() {
            let subject = Subject()

            subject.beginIfIdle()
            subject.finalizeIfDrawing()
            #expect(subject.phase == .finalizing(cancelled: false))

            subject.complete()

            #expect(subject.phase == .idle)
        }

        @Test
        func `Verify that reset transitions to idle from finalizing`() {
            let subject = Subject()

            subject.beginIfIdle()
            subject.finalizeIfDrawing()
            #expect(subject.phase == .finalizing(cancelled: false))

            subject.reset()

            #expect(subject.phase == .idle)
        }
    }

    @MainActor
    @Suite
    struct `Invalid cases` {
        @Test
        func `Verify that beginIfIdle does nothing when phase is already drawing`() {
            let subject = Subject()

            subject.beginIfIdle()
            #expect(subject.phase == .drawing)

            subject.beginIfIdle()

            #expect(subject.phase == .drawing)
        }

        @Test
        func `Verify that finalizeIfDrawing does nothing when phase is idle`() {
            let subject = Subject()

            subject.finalizeIfDrawing()

            #expect(subject.phase == .idle)
        }

        @Test
        func `Verify that finalizeIfDrawing does nothing when phase is already finalizing`() {
            let subject = Subject()

            subject.beginIfIdle()
            subject.finalizeIfDrawing()
            #expect(subject.phase == .finalizing(cancelled: false))

            subject.finalizeIfDrawing()

            #expect(subject.phase == .finalizing(cancelled: false))
        }

        @Test
        func `Verify that complete does nothing when phase is idle`() {
            let subject = Subject()

            subject.complete()

            #expect(subject.phase == .idle)
        }

        @Test
        func `Verify that complete does nothing when phase is drawing`() {
            let subject = Subject()

            subject.beginIfIdle()
            #expect(subject.phase == .drawing)

            subject.complete()

            #expect(subject.phase == .drawing)
        }
    }

    @MainActor
    @Suite
    struct ShouldRunDisplayLink {
        @MainActor
        @Suite
        struct TrueCases {
            @Test
            func `Verify that shouldRunDisplayLink is true while drawing`() {
                let subject = Subject()

                subject.beginIfIdle()

                #expect(subject.shouldRunDisplayLink == true)
            }
        }

        @MainActor
        @Suite
        struct FalseCases {
            @Test
            func `Verify that shouldRunDisplayLink is false while idle`() {
                let subject = Subject()

                #expect(subject.shouldRunDisplayLink == false)
            }

            @Test(
                arguments: [
                    false,
                    true
                ]
            )
            func `Verify that shouldRunDisplayLink is false while finalizing`(cancelled: Bool) {
                let subject = Subject()

                subject.beginIfIdle()
                subject.finalizeIfDrawing(cancelled: cancelled)

                #expect(subject.shouldRunDisplayLink == false)
            }

            @Test
            func `Verify that shouldRunDisplayLink is false after complete`() {
                let subject = Subject()

                subject.beginIfIdle()
                subject.finalizeIfDrawing()
                subject.complete()

                #expect(subject.shouldRunDisplayLink == false)
            }
        }
    }
}
