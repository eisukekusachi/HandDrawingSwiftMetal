//
//  CommandEncoder.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

import Foundation
import MetalKit

protocol CommandQueue {
    
    var buffer: MTLCommandBuffer? { get }
    var queue: MTLCommandQueue { get }
    
    mutating func getBuffer() -> MTLCommandBuffer
    mutating func disposeCommands()
}

struct CommandQueueImpl: CommandQueue {
    
    var buffer: MTLCommandBuffer?
    var queue: MTLCommandQueue
    
    init(queue: MTLCommandQueue) {
        self.queue = queue
    }
    
    mutating func getBuffer() -> MTLCommandBuffer {
        if buffer == nil {
            buffer = queue.makeCommandBuffer()
        }
        return buffer!
    }
    mutating func disposeCommands() {
        self.buffer = nil
    }
}
