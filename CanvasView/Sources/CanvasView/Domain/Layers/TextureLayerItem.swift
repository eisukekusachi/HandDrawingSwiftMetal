//
//  TextureLayerItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import UIKit

public struct TextureLayerItem: Identifiable {
    /// The unique identifier for the layer
    public let id: LayerId
    /// The name of the layer
    public let title: String
    /// The opacity of the layer
    public let alpha: Int
    /// Whether the layer is visible or not
    public let isVisible: Bool

    public let thumbnail: UIImage?

    public var fileName: String {
        id.uuidString
    }

    public init(
        id: LayerId,
        title: String = "",
        alpha: Int = 255,
        isVisible: Bool = true,
        thumbnail: UIImage?
    ) {
        self.id = id
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
        self.thumbnail = thumbnail
    }
}

extension TextureLayerItem {
    public init(
        model: TextureLayerModel,
        thumbnail: UIImage? = nil
    ) {
        self.init(
            id: model.id,
            title: model.title,
            alpha: model.alpha,
            isVisible: model.isVisible,
            thumbnail: thumbnail
        )
    }
}
