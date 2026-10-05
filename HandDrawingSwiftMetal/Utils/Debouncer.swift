//
//  Created by Eisuke Kusachi
//

import Foundation

final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval

    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
    }

    /// Schedules an async throwing block to run after `delay` seconds.
    /// Previous scheduled work is cancelled.
    func perform(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { block() }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
