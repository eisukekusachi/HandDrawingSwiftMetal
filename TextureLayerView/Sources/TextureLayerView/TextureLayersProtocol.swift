//
//  Created by Eisuke Kusachi
//

import Combine
import Foundation

/// The layer list displayed and edited by `TextureLayerView`.
@MainActor
public protocol TextureLayersProtocol: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {

    /// Layers shown in the list.
    var layers: [TextureLayerItem] { get }

    /// Identifier of the selected layer.
    var selectedLayerId: LayerId? { get }

    /// Inserts a new layer.
    func addLayer() async throws

    /// Removes the layer with `id`. Returns whether a layer was removed.
    func removeLayer(id: LayerId) async throws -> Bool

    /// Changes the title of the layer with `id`.
    func renameLayer(id: LayerId, title: String) throws

    /// Moves layers from `source` to `destination`.
    func moveLayers(from source: IndexSet, to destination: Int) throws

    /// Selects the layer with `id`.
    func selectLayer(id: LayerId) throws

    /// Sets whether the layer with `id` is visible.
    func setVisibility(id: LayerId, isVisible: Bool) throws

    /// Sets the opacity of the layer with `id`.
    func setAlpha(id: LayerId, alpha: Int)

    /// Reports whether the opacity slider is being dragged.
    func setAlphaSliderDragging(_ isDragging: Bool)
}
