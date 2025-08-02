//
//  TextureLayerModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/02.
//

import UIKit

public final class TextureLayerModel: Identifiable, Equatable, ObservableObject {

    /// Uses the ID as the filename
    static func fileName(id: UUID) -> String {
        id.uuidString
    }

    /// The unique identifier for the layer
    public var id: UUID

    @Published public var thumbnail: UIImage?

    /// The name of the layer
    @Published public var title: String

    /// The opacity of the layer
    @Published public var alpha: Int

    /// Whether the layer is visible or not
    @Published public var isVisible: Bool

    public init(id: UUID, title: String, alpha: Int, isVisible: Bool) {
        self.id = id
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
    }

    public init(item: TextureLayerItem) {
        self.id = item.id
        self.title = item.title
        self.alpha = item.alpha
        self.isVisible = item.isVisible
    }

    public static func == (lhs: TextureLayerModel, rhs: TextureLayerModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.alpha == rhs.alpha &&
        lhs.isVisible == rhs.isVisible
    }

    /// Retrieve the UUID from the file name since it uses a UUID
    static func id(from string: String?) -> UUID {
        UUID.init(uuidString: string ?? "") ?? UUID()
    }
}
