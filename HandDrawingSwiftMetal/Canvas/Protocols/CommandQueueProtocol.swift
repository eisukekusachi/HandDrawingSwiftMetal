//
//  CommandQueueProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit

protocol CommandQueueProtocol {

    var queue: MTLCommandQueue { get }

    func getOrCreateCommandBuffer() -> MTLCommandBuffer
    func getNewCommandBuffer() -> MTLCommandBuffer
    
    func clearCommandBuffer()
}
