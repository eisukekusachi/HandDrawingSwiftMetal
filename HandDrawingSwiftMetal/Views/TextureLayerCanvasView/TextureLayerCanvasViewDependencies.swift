//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core

/// Dependencies injected into `TextureLayerCanvasView` for layer compositing and texture access.
@MainActor
public final class TextureLayerCanvasViewDependencies {

    /// Layer list and selection used when compositing the canvas.
    public let textureLayers: TextureLayersCompositingProtocol

    /// Repository for layer texture data on disk.
    public let documentsTextureDataRepository: MTLTextureDataRepositoryProtocol

    /// Metal rendering used for compositing and drawing.
    public let renderer: MTLRendering

    public init(
        textureLayers: TextureLayersCompositingProtocol,
        documentsTextureDataRepository: MTLTextureDataRepositoryProtocol,
        renderer: MTLRendering
    ) {
        self.textureLayers = textureLayers
        self.documentsTextureDataRepository = documentsTextureDataRepository
        self.renderer = renderer
    }
}
