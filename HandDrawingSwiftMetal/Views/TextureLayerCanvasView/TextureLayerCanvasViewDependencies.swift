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
    public let localTextureFileRepository: MTLTextureDataRepositoryProtocol

    /// Metal rendering used for compositing and drawing.
    public let renderer: MTLRendering

    public init(
        textureLayers: TextureLayersCompositingProtocol,
        localTextureFileRepository: MTLTextureDataRepositoryProtocol,
        renderer: MTLRendering
    ) {
        self.textureLayers = textureLayers
        self.localTextureFileRepository = localTextureFileRepository
        self.renderer = renderer
    }
}
