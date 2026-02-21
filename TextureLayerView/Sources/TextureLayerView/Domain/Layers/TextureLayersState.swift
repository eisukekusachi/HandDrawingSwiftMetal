//
//  TextureLayersState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import CanvasView
import CoreData
import UIKit

/// A struct that represents the state of TextureLayers. Its layers property is never empty
public struct TextureLayersState: Sendable {

    public let layers: [TextureLayerModel]

    public let layerIndex: Int

    public let textureSize: CGSize

    public init(
        layers: [TextureLayerModel] = [],
        layerIndex: Int = 0,
        textureSize: CGSize
    ) {
        if layers.isEmpty {
            self.layers = [
                .init(
                    id: LayerId(),
                    title: TimeStampFormatter.currentDate,
                    alpha: 255,
                    isVisible: true
                )
            ]
        } else {
            self.layers = layers
        }
        self.layerIndex = min(layerIndex, self.layers.count - 1)
        self.textureSize = textureSize
    }
}

public extension TextureLayersState {
    init(
        model: TextureLayersArchiveModel
    ) throws {
        self.layers = model.layers
        self.layerIndex = model.layerIndex
        self.textureSize = model.textureSize

        // Return an error if the layers are nil or the texture size is zero
        if layers.isEmpty || textureSize == .zero {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Unable to find texture layer files", bundle: .main)
            )
            Logger.error(error)
            throw error
        }
    }

    var selectedLayerId: LayerId? {
        guard !layers.isEmpty else { return nil }

        let index = layerIndex < layers.count ? layerIndex : 0
        return layers[index].id
    }
}
