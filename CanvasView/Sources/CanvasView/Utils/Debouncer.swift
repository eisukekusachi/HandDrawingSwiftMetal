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

    /// Schedules an async throwing block to run after `delay` seconds.
    /// Previous scheduled work is cancelled.
    func schedule(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { block() }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
