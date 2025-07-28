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

    let drawingTool: Int

    let brushDiameter: Int
    let eraserDiameter: Int
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

        self.drawingTool = canvasState.drawingTool.rawValue

        self.brushDiameter = canvasState.brush.diameter
        self.eraserDiameter = canvasState.eraser.diameter
    }

    init(fileURL: URL) throws {
        if let entity: CanvasEntity = try FileInput.loadJson(fileURL) {
            self.thumbnailName = entity.thumbnailName

            self.textureSize = entity.textureSize

            self.layerIndex = entity.layerIndex
            self.layers = entity.layers

            self.drawingTool = entity.drawingTool
            self.brushDiameter = entity.brushDiameter
            self.eraserDiameter = entity.eraserDiameter

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

            self.drawingTool = entity.drawingTool ?? 0
            self.brushDiameter = entity.brushDiameter ?? 8
            self.eraserDiameter = entity.eraserDiameter ?? 8

        } else {
            throw CanvasEntityError.operationError("getCanvasEntity(fileURL:)")
        }
    }
}

extension CanvasEntity: LocalFileConvertible {
    public func write(to url: URL) throws {
        try FileOutput.saveJson(self, to: url)
    }
}

enum CanvasEntityError: Error {
    case operationError(String)
}
