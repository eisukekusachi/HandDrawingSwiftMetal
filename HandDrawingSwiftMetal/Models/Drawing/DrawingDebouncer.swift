//
//  DrawingDebouncer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/22.
//

import Foundation

/// A debouncer to prevent heavy processing from running continuously during drawing
public final class DrawingDebouncer {

    private let debouncer: Debouncer

    public init(delay: TimeInterval) {
        self.debouncer = Debouncer(delay: delay)
    }

    public func perform(
        _ block: @escaping @Sendable () async throws -> Void
    ) {
        debouncer.perform {
            Task {
                do {
                    try await block()
                } catch {
                    // Do nothing if an error occurs
                    Logger.error(error)
                }
            }
        }
    }
}
