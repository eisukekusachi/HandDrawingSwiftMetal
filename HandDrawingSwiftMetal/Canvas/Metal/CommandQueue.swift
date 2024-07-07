//
//  CommandEncoder.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

import MetalKit

class CommandQueue: CommandQueueProtocol {
    let queue: MTLCommandQueue

    private var buffer: MTLCommandBuffer?

    init(queue: MTLCommandQueue) {
        self.queue = queue
    }

    /// Return the buffer if available, create the buffer if not.
    func getOrCreateCommandBuffer() -> MTLCommandBuffer {
        if buffer == nil {
            buffer = queue.makeCommandBuffer()
        }
        return buffer!
    }
    func getNewCommandBuffer() -> MTLCommandBuffer {
        queue.makeCommandBuffer()!
    }

    func clearCommandBuffer() {
        self.buffer = nil
    }
}
