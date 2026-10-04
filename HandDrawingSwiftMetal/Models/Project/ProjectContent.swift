//
//  Created by Eisuke Kusachi
//

import TextureLayerView
import UIKit

/// Snapshot of a project used for Documents zip read / write.
struct ProjectContent {
    let thumbnail: UIImage?
    /// `nil` when texture restore fails on load.
    let textureLayers: TextureLayersSnapshot?
    let project: ProjectSnapshot
    let drawingTool: DrawingToolSnapshot?
    let brushPalette: BrushPaletteSnapshot?
    let eraserPalette: EraserPaletteSnapshot?
}
