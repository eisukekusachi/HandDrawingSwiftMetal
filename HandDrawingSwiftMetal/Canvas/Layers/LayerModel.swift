//
//  LayerModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit

struct LayerModel: Identifiable, Equatable {
    let id: UUID
    var texture: MTLTexture?
    var title: String
    var thumbnail: UIImage?
    var isVisible: Bool
    var alpha: Int

    init(texture: MTLTexture?,
         title: String,
         isVisible: Bool = true,
         alpha: Int = 255) {
        self.id = UUID()
        self.texture = texture
        self.title = title
        self.isVisible = isVisible
        self.alpha = alpha
        
        updateThumbnail()
    }

    mutating func updateThumbnail() {
        thumbnail = texture?.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: LayerModel, rhs: LayerModel) -> Bool {
        lhs.id == rhs.id
    }
}

extension LayerModel {
    static func convertToLayerModelCodableArray(layers: [LayerModel],
                                                fileIO: FileIO,
                                                folderURL: URL) async throws -> [LayerModelCodable] {
        var resultLayers: [LayerModelCodable] = []

        let tasks = layers.map { layer in
            Task<LayerModelCodable?, Error> {
                do {
                    if let texture = layer.texture {
                        let textureName = UUID().uuidString

                        try fileIO.saveImage(bytes: texture.bytes,
                                             to: folderURL.appendingPathComponent(textureName))

                        return LayerModelCodable.init(textureName: textureName,
                                                      title: layer.title,
                                                      isVisible: layer.isVisible,
                                                      alpha: layer.alpha)
                    } else {
                        return nil
                    }

                } catch {
                    return nil
                }
            }
        }

        for task in tasks {
            if let fileURL = try? await task.value {
                resultLayers.append(fileURL)
            }
        }

        return resultLayers.compactMap { $0 }
    }
}
