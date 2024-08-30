//
//  CanvasCurrentTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/29.
//

import Foundation
import MetalKit

final class CanvasCurrentTexture {

    /// The texture of the selected layer
    private (set) var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

}

extension CanvasCurrentTexture {

    func initTexture(textureSize: CGSize) {
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
    }

    func clearTexture() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        MTLRenderer.clear(texture: currentTexture, commandBuffer)
        commandBuffer.commit()
    }

}
