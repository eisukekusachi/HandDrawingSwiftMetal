//
//  Debouncer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/10/11.
//

import Foundation

final class Debouncer {
    private var task: Task<Void, Error>?

    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval

    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
    }

    func schedule(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { block() }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func scheduleAsync(_ block: @MainActor @escaping () async throws -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { Task { try await block() } }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Schedules an async throwing block to run after `delay` seconds.
    /// Previous scheduled work is cancelled.
    @discardableResult
    func schedule(
        _ block: @Sendable @escaping () async throws -> Void
    ) -> Task<Void, Error> {

        task?.cancel()

        let newTask = Task.detached(priority: .background) { [delay] in
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try Task.checkCancellation()
            try await block()
        }

        task = newTask
        return newTask
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
