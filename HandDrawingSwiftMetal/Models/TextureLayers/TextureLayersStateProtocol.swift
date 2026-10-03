//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import MetalKit
import TextureLayerCanvasView
import TextureLayerView

/// The layer list shown in `TextureLayerView` and the layer data read by the canvas.
@MainActor
protocol TextureLayersStateProtocol: TextureLayersProtocol, TextureLayerCanvasProtocol {

    var selectedLayer: TextureLayerModel? { get }

    /// Snapshot of the current layers for persistence.
    var snapshot: TextureLayersSnapshot { get }

    func setup(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        canvasView: TextureLayerCanvasView
    )

    /// Restores the layer list from a saved snapshot.
    func setLayers(_ textureLayers: TextureLayersSnapshot)

    func setLayers(
        _ layers: [TextureLayerModel],
        textureSize: CGSize,
        selectedIndex: Int
    )
}

extension TextureLayersStateProtocol {

    func setLayers(
        _ layers: [TextureLayerModel],
        textureSize: CGSize
    ) {
        setLayers(layers, textureSize: textureSize, selectedIndex: 0)
    }
}
