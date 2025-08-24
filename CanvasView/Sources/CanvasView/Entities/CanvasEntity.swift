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
}

extension CanvasEntity {

    static let thumbnailName: String = "thumbnail.png"

    static let jsonFileName: String = "data"

    static let thumbnailLength: CGFloat = 500

    init(
        thumbnailName: String,
        canvasState: CanvasState
    ) {
        self.thumbnailName = thumbnailName

        self.textureSize = canvasState.textureSize
        self.layerIndex = canvasState.selectedIndex ?? 0
        self.layers = canvasState.layers.map { .init(from: $0) }
    }

    init(fileURL: URL) throws {
        if let entity: CanvasEntity = try FileInput.loadJson(fileURL) {
            self = entity

        } else if let entity: OldCanvasEntity = try FileInput.loadJson(fileURL) {
            self.thumbnailName = entity.thumbnailName ?? ""

            self.textureSize = entity.textureSize ?? .zero

            self.layerIndex = 0
            self.layers = [.init(
                textureName: entity.textureName ?? "",
                title: "NewLayer",
                alpha: 255,
                isVisible: true)
            ]

        } else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
    }
}

extension CanvasEntity: LocalFileConvertible {
    public func write(to url: URL) throws {
        try FileOutput.saveJson(self, to: url)
    }
}
