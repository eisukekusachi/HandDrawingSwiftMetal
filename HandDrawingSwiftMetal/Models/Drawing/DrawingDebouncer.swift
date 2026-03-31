//
//  DrawingDebouncer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/22.
//

import Combine
import Foundation

/// A debouncer to prevent heavy processing from running continuously during drawing
public final class DrawingDebouncer {

    /// A publisher that emits a Bool to indicate processing and completion states
    var isProcessing: AnyPublisher<Bool, Never> {
        isProcessingSubject.eraseToAnyPublisher()
    }
    private let isProcessingSubject: PassthroughSubject<Bool, Never> = .init()

    private let debouncer: Debouncer

    public init(delay: TimeInterval) {
        self.debouncer = Debouncer(delay: delay)
    }

    public func perform(
        _ block: @escaping () async throws -> Void
    ) {
        isProcessingSubject.send(true)

        debouncer.perform {
            Task { [weak self] in
                defer {
                    self?.isProcessingSubject.send(false)
                }

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
