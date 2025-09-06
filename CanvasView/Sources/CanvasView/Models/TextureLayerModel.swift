//
//  TextureLayerModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/02.
//

import UIKit

public final class TextureLayerModel: Identifiable, Codable, Equatable, Sendable {

    /// The unique identifier for the layer
    public let textureName: String

    /// The name of the layer
    public let title: String

    /// The opacity of the layer
    public let alpha: Int

    /// Whether the layer is visible or not
    public let isVisible: Bool


    /// Retrieve the UUID from the file name since it uses a UUID
    public var id: UUID {
        UUID.init(uuidString: textureName) ?? UUID()
    }

    public init(id: UUID, title: String, alpha: Int, isVisible: Bool) {
        self.textureName = id.uuidString
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
    }

    public static func == (lhs: TextureLayerModel, rhs: TextureLayerModel) -> Bool {
        lhs.textureName == rhs.textureName &&
        lhs.title == rhs.title &&
        lhs.alpha == rhs.alpha &&
        lhs.isVisible == rhs.isVisible
    }

    /// Retrieve the UUID from the file name since it uses a UUID
    static func id(fromFileName string: String?) -> UUID {
        UUID.init(uuidString: string ?? "") ?? UUID()
    }
}

extension TextureLayerModel {
    public convenience init(item: TextureLayerItem) {
        self.init(
            id: item.id,
            title: item.title,
            alpha: item.alpha,
            isVisible: item.isVisible
        )
    }
}
