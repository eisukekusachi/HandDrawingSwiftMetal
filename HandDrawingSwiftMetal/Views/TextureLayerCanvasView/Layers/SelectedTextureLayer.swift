//
//  Created by Eisuke Kusachi
//

import MetalKit

/// The selected layer currently composited onto the canvas, with its `MTLTexture`, opacity, and visibility.
/// `texture` is the in-progress stroke or the displayed texture.
struct SelectedTextureLayer {

    /// Whether this layer is included in the composite.
    let isVisible: Bool

    /// Opacity used when merging `texture` into the canvas.
    let alpha: Int

    /// The `MTLTexture` drawn for this layer.
    let texture: MTLTexture?
}
