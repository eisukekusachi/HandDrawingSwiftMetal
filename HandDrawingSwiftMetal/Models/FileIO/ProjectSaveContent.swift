//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/25.
//

import UIKit
import TextureLayerView

struct ProjectSaveContent {
    let thumbnail: UIImage?
    let textureLayersState: TextureLayersState
    let project: ProjectData
    let drawingTool: DrawingTool
    let brushPalette: BrushPalette
    let eraserPalette: EraserPalette
}
