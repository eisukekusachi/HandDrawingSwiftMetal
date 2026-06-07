//
//  TransformLifecycleTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/07.
//

import Testing

@testable import CanvasView

@MainActor
struct TransformLifecycleTests {

    struct isActive {
        @Test(
            arguments: [
                TransformLifecycle.idle
            ]
        )
        func `lifecycle is not active`(state: TransformLifecycle) {
            #expect(state.isActive == false)
        }

        @Test(
            arguments: [
                TransformLifecycle.transforming,
                TransformLifecycle.finalizing
            ]
        )
        func `lifecycle is active`(state: TransformLifecycle) {
            #expect(state.isActive == true)
        }
    }
}
