//
//  TextureLayersArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

public struct TextureLayersArchiveModel: Codable, Equatable {

    let textureSize: CGSize
    let layerIndex: Int
    let layers: [TextureLayerModel]

    public init(
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerModel]
    ) {
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

extension TextureLayersArchiveModel {

    public static let thumbnailName: String = "thumbnail.png"

    public static let fileName: String = "data"

    public static let thumbnailLength: CGFloat = 500

    @MainActor
    public init(
        textureLayers: any TextureLayersProtocol
    ) {
        self.textureSize = textureLayers.textureSize
        self.layerIndex = textureLayers.selectedIndex ?? 0
        self.layers = textureLayers.layers.map { .init(item: $0) }
    }

    /// Initializes by decoding a JSON file at the given URL
    public init(fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        do {
            self = try JSONDecoder().decode(TextureLayersArchiveModel.self, from: data)
        } catch {
            let className = String(describing: TextureLayersArchiveModel.self)
            let nsError = NSError(
                domain: className,
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to decode \(className) from JSON.",
                    NSUnderlyingErrorKey: error,
                    "fileURL": fileURL.path
                ]
            )
            Logger.error(nsError)
            throw nsError
        }
    }
}

extension TextureLayersArchiveModel: LocalFileConvertible {

    public func namedItem() -> LocalFileNamedItem<TextureLayersArchiveModel> {
        .init(
            fileName: TextureLayersArchiveModel.fileName,
            item: self
        )
    }

    public func write(to url: URL) throws {
        try FileOutput.saveJson(self, to: url)
    }
}
