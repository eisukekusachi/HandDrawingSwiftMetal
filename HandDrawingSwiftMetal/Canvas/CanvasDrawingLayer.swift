//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation
import MetalKit

protocol CanvasDrawingLayer {
    
    var textureSize: CGSize { get }
    
    var canvas: CanvasDrawingProtocol { get }
    
    var currentLayer: [MTLTexture?] { get }
    
    init(canvas: CanvasDrawingProtocol)
    func initalizeTextures(textureSize: CGSize)
    
    func drawOnDrawingLayer(with iterator: Iterator<Point>, touchState: TouchState)
    func mergeDrawingLayerIntoCurrentLayer()
    func clear()
}
