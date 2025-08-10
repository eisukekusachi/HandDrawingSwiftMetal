//
//  TextureLayerItem.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import CanvasView
import Foundation

public extension TextureLayerItem {

    static func generate(
        id: UUID = UUID(),
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
