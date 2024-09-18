//
//  MTLCommandManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/09/15.
//

import MetalKit

final class MTLCommandManager {

    private let queue: MTLCommandQueue

    /// Return the buffer if available, create the buffer if not.
    var currentCommandBuffer: MTLCommandBuffer {
        if storedBuffer == nil {
            storedBuffer = queue.makeCommandBuffer()
        }
        return storedBuffer!
    }

    private var storedBuffer: MTLCommandBuffer?

    init(device: MTLDevice) {
        let newQueue = device.makeCommandQueue()!
        self.queue = newQueue
    }

    func clearCurrentCommandBuffer() {
        self.storedBuffer = nil
    }

}
