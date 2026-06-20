//
//  StrokeLifecycleTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/15.
//

import Testing

@testable import CanvasView

@MainActor
struct StrokeLifecycleTests {

    @Suite
    struct IsActive {
        @Test
        func `Verify that idle phase is not active`() {
            #expect(StrokeLifecycle.idle.isActive == false)
        }

        @Test(
            arguments: [
                StrokeLifecycle.drawing,
                StrokeLifecycle.finalizing(cancelled: false),
                StrokeLifecycle.finalizing(cancelled: true)
            ]
        )
        func `Verify that drawing and finalizing phases are active`(state: StrokeLifecycle) {
            #expect(state.isActive == true)
        }
    }

    @Suite
    struct IsDrawing {
        @Test
        func `Verify that isDrawing is true while drawing`() {
            #expect(StrokeLifecycle.drawing.isDrawing == true)
        }

        @Test(
            arguments: [
                StrokeLifecycle.idle,
                StrokeLifecycle.finalizing(cancelled: false),
                StrokeLifecycle.finalizing(cancelled: true)
            ]
        )
        func `Verify that isDrawing is false outside drawing`(state: StrokeLifecycle) {
            #expect(state.isDrawing == false)
        }
    }
}
