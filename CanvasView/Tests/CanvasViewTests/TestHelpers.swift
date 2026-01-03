//
//  TestHelpers.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/01/03.
//

import Foundation

/// Repeatedly evaluates `condition` at the given interval until it becomes `true` or the timeout is reached
@MainActor
struct TestHelpers {

    static func waitUntil(
        _ condition: () -> Bool,
        interval: UInt64 = 10_000_000,   // 10ms
        timeout: UInt64 = 500_000_000    // 500ms
    ) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeout {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: interval)
        }
        return condition()
    }
}
