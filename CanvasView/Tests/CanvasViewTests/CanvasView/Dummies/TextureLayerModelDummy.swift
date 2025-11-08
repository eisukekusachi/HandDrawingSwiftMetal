//
//  TextureLayerModelDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import CanvasView
import MetalKit

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
