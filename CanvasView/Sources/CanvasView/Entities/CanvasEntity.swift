//
//  CanvasEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

public struct CanvasEntity: Codable, Equatable {

    let textureSize: CGSize
    let layerIndex: Int
    let layers: [TextureLayerEntity]

    let thumbnailName: String

    public init(textureSize: CGSize, layerIndex: Int, layers: [TextureLayerEntity], thumbnailName: String) {
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
        self.thumbnailName = thumbnailName
    }
}

extension CanvasEntity {

    static let thumbnailName: String = "thumbnail.png"

    static let jsonFileName: String = "data"

    static let thumbnailLength: CGFloat = 500

    init(
        canvasState: CanvasState
    ) {
        self.thumbnailName = CanvasEntity.thumbnailName

        self.textureSize = canvasState.textureSize
        self.layerIndex = canvasState.selectedIndex ?? 0
        self.layers = canvasState.layers.map { .init(from: $0) }
    }

    init(fileURL: URL, candidates: [CanvasEntityConvertible.Type]) throws {
        let decoder = JSONDecoder()
        let jsonString: String = try String(contentsOf: fileURL, encoding: .utf8)
        let dataJson = jsonString.data(using: .utf8) ?? Data()

        for type in candidates {
            if let decoded = try? decoder.decode(type, from: dataJson) {
                self = decoded.entity()
                return
            }
        }

        let error = NSError(
            domain: "CanvasEntity",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to decode CanvasEntity"]
        )
        Logger.error(error)
        throw error
    }
}

extension CanvasEntity: CanvasEntityConvertible {
    public func entity() -> CanvasEntity {
        self
    }
}

extension CanvasEntity: LocalFileConvertible {

    public static func namedItem(_ canvasState: CanvasState) -> LocalFileNamedItem<CanvasEntity> {
        .init(
            fileName: CanvasEntity.jsonFileName,
            item: .init(
                canvasState: canvasState
            )
        )
    }

    public func write(to url: URL) throws {
        try FileOutput.saveJson(self, to: url)
    }
}
