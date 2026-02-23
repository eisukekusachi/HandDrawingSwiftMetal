//
//  TextureLayerModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/02.
//

import UIKit

public struct TextureLayerModel: Identifiable, Codable, Equatable, Sendable {

    /// The unique identifier for the layer
    public let id: LayerId

    /// The name of the layer
    public let title: String

    /// The opacity of the layer
    public let alpha: Int

    /// Whether the layer is visible or not
    public let isVisible: Bool

    public var fileName: String {
        id.uuidString
    }

    public init(
        id: LayerId,
        title: String,
        alpha: Int,
        isVisible: Bool
    ) {
        self.id = id
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
    }
}

extension TextureLayerModel {

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case alpha
        case isVisible
        // legacy
        case textureName
    }

    public init(item: TextureLayerItem) {
        self.init(
            id: item.id,
            title: item.title,
            alpha: item.alpha,
            isVisible: item.isVisible
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id: LayerId
        if let decodedID = try? container.decode(LayerId.self, forKey: .id) {
            id = decodedID
        } else if let legacyIDString = try? container.decode(String.self, forKey: .textureName),
                  let legacyID = LayerId(uuidString: legacyIDString) {
            id = legacyID
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing `id` or legacy `textureName`."
                )
            )
        }

        let title = try container.decode(String.self, forKey: .title)
        let alpha = try container.decode(Int.self, forKey: .alpha)
        let isVisible = try container.decode(Bool.self, forKey: .isVisible)

        self.init(id: id, title: title, alpha: alpha, isVisible: isVisible)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(isVisible, forKey: .isVisible)
    }

    public static func == (lhs: TextureLayerModel, rhs: TextureLayerModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.alpha == rhs.alpha &&
        lhs.isVisible == rhs.isVisible
    }

    /// Retrieve the '`LayerId` from the file name since it uses a `LayerId`
    static func id(fromFileName string: String?) -> LayerId {
        LayerId.init(uuidString: string ?? "") ?? LayerId()
    }
}
