//
//  ProjectContent.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/25.
//

import TextureLayerView
import UIKit

/// Snapshot of a project used for Documents zip read / write.
struct ProjectContent {
    let thumbnail: UIImage?
    /// `nil` when texture restore fails on load.
    let textureLayers: TextureLayersSnapshot?
    let project: ProjectArchiveModel
    let drawingTool: DrawingToolArchiveModel?
    let brushPalette: BrushPaletteArchiveModel?
    let eraserPalette: EraserPaletteArchiveModel?
}
