//
//  Created by Eisuke Kusachi
//

@MainActor
struct TextureLayerSelection {

    let textureLayers: TextureLayers

    var bottomLayers: [CanvasLayerSnapshot] {
        textureLayers.layers.safeSlice(
            lower: 0,
            upper: textureLayers.selectedIndex - 1
        ).filter { $0.isVisible }
    }

    var topLayers: [CanvasLayerSnapshot] {
        textureLayers.layers.safeSlice(
            lower: textureLayers.selectedIndex + 1,
            upper: textureLayers.layers.count - 1
        ).filter { $0.isVisible }
    }
}
