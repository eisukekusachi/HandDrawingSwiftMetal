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
}
