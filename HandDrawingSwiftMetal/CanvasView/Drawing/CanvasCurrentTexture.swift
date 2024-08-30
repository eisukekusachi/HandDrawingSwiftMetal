//
//  CanvasCurrentTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/29.
//

import Foundation
import MetalKit

final class CanvasCurrentTexture {

    /// A texture on which the texture of the currently selected layer and the texture currently being drawn are rendered
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
