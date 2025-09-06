//
//  CanvasEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

public struct CanvasModel: Codable, Equatable {

    let textureSize: CGSize
    let layerIndex: Int
    let layers: [TextureLayerModel]

    let thumbnailName: String

    public init(
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerModel],
        thumbnailName: String
    ) {
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
        self.thumbnailName = thumbnailName
    }
}

extension CanvasModel {

    static let thumbnailName: String = "thumbnail.png"

    static let jsonFileName: String = "data"

    static let thumbnailLength: CGFloat = 500

    init(
        canvasState: CanvasState
    ) {
        self.textureSize = canvasState.textureSize
        self.layerIndex = canvasState.selectedIndex ?? 0
        self.layers = canvasState.layers.map { .init(item: $0) }
        self.thumbnailName = CanvasModel.thumbnailName
    }

    /// Initializes a CanvasEntity by decoding a JSON file at the given URL into a CanvasModel
    init(fileURL: URL) throws {
        let decoder = JSONDecoder()
        let jsonString: String = try String(contentsOf: fileURL, encoding: .utf8)
        let dataJson = jsonString.data(using: .utf8) ?? Data()

        if let decoded = try? decoder.decode(CanvasModel.self, from: dataJson) {
            self = decoded.model()
            return
        }

        let error = NSError(
            domain: "CanvasModel",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to decode CanvasModel"]
        )
        Logger.error(error)
        throw error
    }
}

extension CanvasModel: CanvasEntityConvertible {
    public func model() -> CanvasModel {
        self
    }
}

extension CanvasModel: LocalFileConvertible {

    public static func namedItem(_ canvasModel: CanvasModel) -> LocalFileNamedItem<CanvasModel> {
        .init(
            fileName: CanvasModel.jsonFileName,
            item: canvasModel
        )
    }

    public func write(to url: URL) throws {
        try FileOutput.saveJson(self, to: url)
    }
}

public protocol CanvasEntityConvertible: Decodable {
    func model() -> CanvasModel
}
