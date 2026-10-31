//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import TextureLayerView

/// Layer list and selection read when compositing the canvas during drawing.
@MainActor
public protocol TextureLayersCompositingProtocol: AnyObject {
    /// Size of the canvas textures.
    var textureSize: CGSize { get }

    /// Index of the selected layer in `layers`.
    var selectedLayerIndex: Int? { get }

    /// The selected layer's opacity, visibility, and id.
    var selectedLayer: TextureLayerItem? { get }

    /// Layers in stack order.
    var layers: [TextureLayerItem] { get }
}
