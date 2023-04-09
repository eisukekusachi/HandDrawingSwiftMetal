//
//  DefaultLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

class DefaultLayers: CanvasLayers {
    
    var canvas: CanvasTextureLayerProtocol!
    var currentLayer: MTLTexture {
        return layer
    }
    
    var layer: MTLTexture!
    var layerSize: CGSize = .zero
    
    required init(canvas: CanvasTextureLayerProtocol) {
        self.canvas = canvas
    }
    func initalizeLayers(layerSize: CGSize) {
        
        if self.layerSize != layerSize {
            self.layerSize = layerSize
            
            self.layer = canvas.mtlDevice.makeTexture(layerSize)
        }
        
        clear()
    }
    
    func flatAllLayers(currentLayer: [MTLTexture?], backgroundColor: (Int, Int, Int), toDisplayTexture displayTexture: MTLTexture) {
        
        let commandBuffer = canvas.commandBuffer
        
        Command.fill(displayTexture,
                     withRGB: backgroundColor,
                     to: commandBuffer)
        
        Command.merge(dst: displayTexture,
                      textures: currentLayer,
                      to: commandBuffer)
    }
    
    func clear() {
        
        Command.clear(texture: layer, to: canvas.commandBuffer)
    }
}
