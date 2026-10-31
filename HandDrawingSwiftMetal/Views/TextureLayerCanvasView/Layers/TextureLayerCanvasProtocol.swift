//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import TextureLayerView
import UIKit

@MainActor
public protocol TextureLayerCanvasProtocol: AnyObject {

    var textureSize: CGSize { get }

    var selectedLayerIndex: Int? { get }

    var layers: [TextureLayerItem] { get }

    var selectedLayerItem: TextureLayerItem? { get }

    func updateLayerThumbnail(_ id: UUID, thumbnail: UIImage?)
}
