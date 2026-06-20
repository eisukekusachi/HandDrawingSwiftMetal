//
//  StrokePointStateTests.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2026/06/20.
//

import Testing
import UIKit

@testable import CanvasView

@MainActor
struct StrokePointStateTests {

    private typealias Subject = StrokePointState

    @Suite
    struct ShouldFinalizeDrawing {
        @Suite
        struct TrueCases {
            @Test
            func `Verify that shouldFinalizeDrawing is true when the points contain ended`() {
                let subject = Subject(
                    points: [
                        .generate(phase: .moved),
                        .generate(phase: .ended)
                    ]
                )

                #expect(subject.shouldFinalizeDrawing == true)
            }

            @Test
            func `Verify that shouldFinalizeDrawing is true when the points contain cancelled`() {
                let subject = Subject(
                    points: [
                        .generate(phase: .moved),
                        .generate(phase: .cancelled)
                    ]
                )

                #expect(subject.shouldFinalizeDrawing == true)
            }

            @Test
            func `Verify that shouldFinalizeDrawing is true when the last point is ended`() {
                let subject = Subject(
                    points: [
                        .generate(phase: .moved),
                        .generate(phase: .ended)
                    ]
                )

                #expect(subject.shouldFinalizeDrawing == true)
            }
        }

        @Suite
        struct FalseCases {
            @Test
            func `Verify that shouldFinalizeDrawing is false for empty points`() {
                let subject = Subject(points: [])

                #expect(subject.shouldFinalizeDrawing == false)
            }

            @Test(
                arguments: [
                    UITouch.Phase.began,
                    UITouch.Phase.moved,
                    UITouch.Phase.stationary
                ]
            )
            func `Verify that shouldFinalizeDrawing is false while drawing`(phase: UITouch.Phase) {
                let subject = Subject(
                    points: [
                        .generate(phase: phase)
                    ]
                )

                #expect(subject.shouldFinalizeDrawing == false)
            }
        }
    }

    @Suite
    struct DrawingTouchPhase {
        @Test
        func `Verify that cancelled takes priority over ended`() {
            let subject = Subject(
                points: [
                    .generate(phase: .ended),
                    .generate(phase: .cancelled)
                ]
            )

            #expect(subject.drawingTouchPhase == .cancelled)
        }

        @Test
        func `Verify that ended takes priority over began`() {
            let subject = Subject(
                points: [
                    .generate(phase: .began),
                    .generate(phase: .ended)
                ]
            )

            #expect(subject.drawingTouchPhase == .ended)
        }

        @Test
        func `Verify that drawingTouchPhase is nil for empty points`() {
            let subject = Subject(points: [])

            #expect(subject.drawingTouchPhase == nil)
        }
    }
}
