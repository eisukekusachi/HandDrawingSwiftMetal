//
//  Created by Eisuke Kusachi
//

import Combine
import Foundation

@MainActor
public protocol TextureLayersProtocol: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var layers: [TextureLayerItem] { get }
    var selectedLayerId: LayerId? { get }

    func addLayer() async throws
    func removeLayer(id: LayerId) async throws -> Bool
    func renameLayer(id: LayerId, title: String) throws
    func moveLayers(from source: IndexSet, to destination: Int) throws
    func selectLayer(id: LayerId)
    func setVisibility(id: LayerId, isVisible: Bool)
    func setAlpha(id: LayerId, alpha: Int)
    func setAlphaSliderDragging(_ isDragging: Bool)
}
