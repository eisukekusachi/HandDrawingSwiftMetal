//
//  Pipeline.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/30.
//

import Foundation
import MetalKit

enum Pipeline {
    
    static var drawGrayPoints: MTLRenderPipelineState!
    static var drawTexture: MTLRenderPipelineState!
    static var erase: MTLRenderPipelineState!
    static var colorize: MTLComputePipelineState!
    static var merge: MTLComputePipelineState!
    static var fillColor: MTLComputePipelineState!
    static var copy: MTLComputePipelineState!
    
    static func initalization(_ device: MTLDevice) {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create default library with device: \(device.description)")
        }
        
        Pipeline.drawGrayPoints = Pipeline.makeRenderPipelineState(device: device, library: library, label: "Draw Gray Points") { descriptor in
            descriptor.vertexFunction = library.makeFunction(name: "draw_gray_points_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "draw_gray_points_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .max
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        }
        
        Pipeline.drawTexture = Pipeline.makeRenderPipelineState(device: device, library: library, label: "Draw Gray Points") { descriptor in
            descriptor.vertexFunction = library.makeFunction(name: "draw_texture_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "draw_texture_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        Pipeline.erase = Pipeline.makeRenderPipelineState(device: device, library: library, label: "Draw Eraser Points") { descriptor in
            descriptor.vertexFunction = library.makeFunction(name: "draw_texture_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "draw_texture_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .zero
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .zero
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        Pipeline.colorize = Pipeline.makeComputePipieline(device: device,
                                                          library: library,
                                                          label: "Colorize", shaderName: "colorize_grayscale_texture")
        Pipeline.merge = Pipeline.makeComputePipieline(device: device,
                                                       library: library,
                                                       label: "Marge textures", shaderName: "merge_textures")
        Pipeline.fillColor = Pipeline.makeComputePipieline(device: device,
                                                           library: library,
                                                           label: "Add color to a texture", shaderName: "add_color_to_texture")
        Pipeline.copy = Pipeline.makeComputePipieline(device: device,
                                                      library: library,
                                                      label: "Copy a texture", shaderName: "copy_texture")
    }
}

extension Pipeline {
    private static func makeComputePipieline(device: MTLDevice,
                                             library: MTLLibrary,
                                             label: String,
                                             shaderName: String) -> MTLComputePipelineState {
        guard let function = library.makeFunction(name: shaderName) else {
            fatalError("The function is not found in the library.")
        }
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    private static func makeRenderPipelineState(device: MTLDevice,
                                                library: MTLLibrary,
                                                label: String,
                                                block: (MTLRenderPipelineDescriptor) -> Void) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        block(descriptor)
        descriptor.label = label
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
