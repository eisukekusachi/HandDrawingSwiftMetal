//
//  TextureLayersArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Core
import CoreGraphics
import Foundation

struct TextureLayersArchiveModel: Codable, Equatable, Sendable {

    let layers: [TextureLayerModel]
    let layerIndex: Int
    let textureSize: CGSize

    init(
        layers: [TextureLayerModel],
        layerIndex: Int,
        textureSize: CGSize
    ) {
        self.layers = layers
        self.layerIndex = layerIndex
        self.textureSize = textureSize
    }

    func makeTextureLayersSnapshot() throws -> TextureLayersSnapshot {
        if layers.isEmpty || textureSize == .zero {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to find texture layer files")
            )
            Logger.error(error)
            throw error
        }

        return TextureLayersSnapshot(
            layers: layers,
            layerIndex: layerIndex,
            textureSize: textureSize
        )
    }
}

extension TextureLayersArchiveModel: LocalFileConvertible {
    static var fileName: String { "data" }
}
