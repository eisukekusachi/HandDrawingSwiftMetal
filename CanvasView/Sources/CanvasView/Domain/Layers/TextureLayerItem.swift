//
//  TextureLayerItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

public struct TextureLayerItem: Identifiable, Equatable, Sendable {
    /// The unique identifier for the layer
    public let id: UUID
    /// The name of the layer
    public let title: String
    /// The opacity of the layer
    public let alpha: Int
    /// Whether the layer is visible or not
    public let isVisible: Bool

    public init(id: UUID, title: String, alpha: Int, isVisible: Bool) {
        self.id = id
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
    }
}

extension TextureLayerItem {
    public init(model: TextureLayerModel) {
        self.id = model.id
        self.title = model.title
        self.alpha = model.alpha
        self.isVisible = model.isVisible
    }

    public init(
        textureName: String,
        title: String,
        alpha: Int = 255,
        isVisible: Bool = true
    ) {
        self.init(
            id: TextureLayerItem.id(from: textureName),
            title: title,
            alpha: alpha,
            isVisible: isVisible
        )
    }

    public init(
        model: TextureLayerModel,
        id: UUID? = nil,
        title: String? = nil,
        alpha: Int? = nil,
        isVisible: Bool? = nil
    ) {
        self.id = id ?? model.id
        self.title = title ?? model.title
        self.alpha = alpha ?? model.alpha
        self.isVisible = isVisible ?? model.isVisible
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Uses the ID as the filename
    var fileName: String {
        id.uuidString
    }

    /// Retrieve the UUID from the file name since it uses a UUID
    static func id(from string: String?) -> UUID {
        UUID.init(uuidString: string ?? "") ?? UUID()
    }
}
