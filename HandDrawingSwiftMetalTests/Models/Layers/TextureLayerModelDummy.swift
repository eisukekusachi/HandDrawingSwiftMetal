//
//  Created by Eisuke Kusachi
//

import Foundation
import HandDrawingSwiftMetal
import TextureLayerView

public extension TextureLayerModel {

    static func generate(
        id: LayerId = LayerId(),
        title: String = "",
        alpha: Int = 255,
        isVisible: Bool = true
    ) -> Self {
        .init(
            id: id,
            title: title,
            alpha: alpha,
            isVisible: isVisible
        )
    }
}
