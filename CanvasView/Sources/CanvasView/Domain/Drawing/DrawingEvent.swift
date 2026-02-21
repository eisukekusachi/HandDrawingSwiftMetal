//
//  DrawingEvent.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/02/11.
//

import MetalKit

public enum DrawingEvent {
    case fingerStrokeBegan
    case pencilStrokeBegan
    case strokeCompleted(texture: MTLTexture)
}
