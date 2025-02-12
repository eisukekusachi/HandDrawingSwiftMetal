//
//  TextureLayer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit

enum TextureLayerError: Error {
    case cannotCreateTexture
}

/// A layer with a texture
struct TextureLayer: TextureLayerProtocol {
    /// The unique identifier for the layer
    var id: UUID = UUID()
    /// The texture of the layer
    var texture: MTLTexture?
    /// The name of the layer
    var title: String
    /// The thumbnail image of the layer
    var thumbnail: UIImage?
    /// The opacity of the layer
    var alpha: Int = 255
    /// Whether the layer is visible or not
    var isVisible: Bool = true

}

extension TextureLayer {
    init(textureLayer: TextureLayer, withNewTexture newTexture: MTLTexture?) {
        id = textureLayer.id
        title = textureLayer.title
        alpha = textureLayer.alpha
        isVisible = textureLayer.isVisible

        texture = newTexture
        updateThumbnail()
    }

    init(
        from imageLayerEntity: ImageLayerEntity,
        textureSize: CGSize,
        folderURL: URL,
        device: MTLDevice
    ) throws {
        let textureData = try Data(contentsOf: folderURL.appendingPathComponent(imageLayerEntity.textureName))

        guard
            let hexadecimalData = textureData.encodedHexadecimals,
            let texture = MTLTextureCreator.makeTexture(
                size: textureSize,
                colorArray: hexadecimalData,
                with: device
            )
        else {
            throw TextureLayerError.cannotCreateTexture
        }

        self.init(
            texture: texture,
            title: imageLayerEntity.title,
            alpha: imageLayerEntity.alpha,
            isVisible: imageLayerEntity.isVisible
        )
    }

    mutating func updateThumbnail() {
        thumbnail = texture?.upsideDownUIImage?.resizeWithAspectRatio(width: 64)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func getLayerWithNewTexture(withDevice device: MTLDevice, withCommandBuffer commandBuffer: MTLCommandBuffer) -> Self {
        .init(
            textureLayer: self,
            withNewTexture: MTLTextureCreator.duplicateTexture(
                texture: self.texture,
                withDevice: device,
                withCommandBuffer: commandBuffer
            )
        )
    }

    func getLayerWithNewTexture(device: MTLDevice) -> Self {
        .init(
            textureLayer: self,
            withNewTexture: MTLTextureCreator.duplicateTexture(
                texture: self.texture,
                with: device
            )
        )
    }

    static func makeLayers(
        from imageLayerEntities: [ImageLayerEntity],
        textureSize: CGSize,
        folderURL: URL,
        device: MTLDevice
    ) throws -> [TextureLayer] {
        try imageLayerEntities.map { imageLayerEntity in
            try TextureLayer.init(
                from: imageLayerEntity,
                textureSize: textureSize,
                folderURL: folderURL,
                device: device
            )
        }
    }

}
