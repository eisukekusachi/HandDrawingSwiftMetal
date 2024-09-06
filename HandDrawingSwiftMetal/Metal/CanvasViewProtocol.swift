//
//  CanvasViewProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/06.
//

import MetalKit

protocol CanvasViewProtocol {
    var commandBuffer: MTLCommandBuffer { get }

    var renderTexture: MTLTexture? { get }

    var viewDrawable: CAMetalDrawable? { get }

    func initRenderTexture(textureSize: CGSize)

    func clearCommandBuffer()

    func setNeedsDisplay()
}
