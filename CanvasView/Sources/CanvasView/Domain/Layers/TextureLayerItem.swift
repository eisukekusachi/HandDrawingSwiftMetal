//
//  TextureLayerItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import UIKit

public class TextureLayerItem: ObservableObject {
    /// The unique identifier for the layer
    public let id: UUID
    /// The name of the layer
    @Published public var title: String
    /// The opacity of the layer
    @Published public var alpha: Int
    /// Whether the layer is visible or not
    @Published public var isVisible: Bool

    @Published public var thumbnail: UIImage?

    var fileName: String {
        id.uuidString
    }

    public init(
        id: UUID,
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
    public convenience init(
        model: TextureLayerModel,
        thumbnail: UIImage?
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
