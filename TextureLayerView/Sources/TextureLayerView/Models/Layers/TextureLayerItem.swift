//
//  TextureLayerItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import UIKit

/// Presentaion model for `TextureLayerItemView`
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

    /// The background color when the item is not selected
    public let defaultBackgroundColor: UIColor
    /// The background color when the item is selected
    public let selectedBackgroundColor: UIColor

    public let iconSize: CGSize
    public let cornerRadius: CGFloat

    public let padding: CGFloat

    public init(
        id: LayerId,
        title: String = "",
        alpha: Int = 255,
        isVisible: Bool = true,
        thumbnail: UIImage?,
        defaultBackgroundColor: UIColor = .white,
        selectedBackgroundColor: UIColor = .black,
        iconSize: CGSize = .init(width: 32, height: 32),
        padding: CGFloat = 4,
        cornerRadius: CGFloat = 4,
    ) {
        self.id = id
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
        self.thumbnail = thumbnail
        self.defaultBackgroundColor = defaultBackgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.iconSize = iconSize
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
}

public extension TextureLayerItem {
    init(
        model: TextureLayerModel,
        thumbnail: UIImage? = nil,
        defaultBackgroundColor: UIColor = .white,
        selectedBackgroundColor: UIColor = .black,
        iconSize: CGSize = .init(width: 32, height: 32),
        padding: CGFloat = 4,
        cornerRadius: CGFloat = 4,
    ) {
        self.init(
            id: model.id,
            title: model.title,
            alpha: model.alpha,
            isVisible: model.isVisible,
            thumbnail: thumbnail,
            defaultBackgroundColor: defaultBackgroundColor,
            selectedBackgroundColor: selectedBackgroundColor,
            iconSize: iconSize,
            padding: padding,
            cornerRadius: cornerRadius
        )
    }

    func updated(
        title: String? = nil,
        alpha: Int? = nil,
        isVisible: Bool? = nil,
        thumbnail: UIImage? = nil
    ) -> Self {
        .init(
            id: id,
            title: title ?? self.title,
            alpha: alpha ?? self.alpha,
            isVisible: isVisible ?? self.isVisible,
            thumbnail: thumbnail ?? self.thumbnail,
            defaultBackgroundColor: defaultBackgroundColor,
            selectedBackgroundColor: selectedBackgroundColor,
            iconSize: iconSize,
            padding: padding,
            cornerRadius: cornerRadius
        )
    }

    func backgroundColor(_ selected: Bool) -> UIColor {
        !selected ? defaultBackgroundColor : selectedBackgroundColor
    }
    func textColor(_ selected: Bool) -> UIColor {
        !selected ? selectedBackgroundColor : defaultBackgroundColor
    }
    func iconColor(isVisible: Bool, _ selected: Bool) -> UIColor {
        !selected ? selectedBackgroundColor : defaultBackgroundColor
    }
}
