//
//  MTLCommandBufferManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import MetalKit

final class MTLCommandBufferManager {

    private let queue: MTLCommandQueue

    /// Return the buffer if available, create the buffer if not.
    var currentCommandBuffer: MTLCommandBuffer {
        if storedCommandBuffer == nil {
            storedCommandBuffer = queue.makeCommandBuffer()
        }
        return storedCommandBuffer!
    }

    private var storedCommandBuffer: MTLCommandBuffer?

    init(device: MTLDevice) {
        self.queue = device.makeCommandQueue()!
    }

    func clearCurrentCommandBuffer() {
        self.storedCommandBuffer = nil
    }

}
