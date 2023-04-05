//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation
import MetalKit

let initBlurSize: Float = 4.0

struct BlurredSize {
    var diameter: Int
    var blurSize: Float
    var totalSize: Float {
        return Float(diameter) + blurSize * 2
    }
}

protocol Drawing {
    
    var textureSize: CGSize { get }
    
    func initalizeTexturesForDrawing(_ canvas: Canvas, textureSize: CGSize)
    
    func execute(_ iterator: Iterator<Point>?, endProcessing: Bool, toward canvas: CanvasDrawingProtocol)
    func finishExecuting(_ canvas: CanvasDrawingProtocol)
    func refresh(_ canvas: CanvasDrawingProtocol)
    
    func reset(_ canvas: CanvasDrawingProtocol)
}
