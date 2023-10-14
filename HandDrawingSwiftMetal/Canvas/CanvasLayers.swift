//
//  CanvasLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

protocol CanvasLayers {
    
    var canvas: Canvas! { get }
    
    var currentLayer: MTLTexture { get }
    
    var layerSize: CGSize { get }
    
    init(canvas: Canvas)
    func initalizeLayers(layerSize: CGSize)
    
    func flatAllLayers(currentLayer: [MTLTexture?], backgroundColor: (Int, Int, Int), toDisplayTexture displayTexture: MTLTexture)
    func clear()
}
