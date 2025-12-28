//
//  TextureInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation
@preconcurrency import MetalKit

/// A repository that manages in-memory textures
@MainActor
public final class TextureInMemoryRepository {

    public var textureSize: CGSize {
        _textureSize
    }

    /// A dictionary with `LayerId` as the key and MTLTexture as the value
    private(set) var textures: [LayerId: MTLTexture?] = [:]

    private let renderer: MTLRendering

    private var _textureSize: CGSize = .zero

    public init(
        textures: [LayerId: MTLTexture?] = [:],
        renderer: MTLRendering
    ) {
        self.textures = textures
        self.renderer = renderer
    }

    public func initializeStorage(
        textureLayersPersistedState: TextureLayersPersistedState,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayersPersistedState {
        let textureSize = textureLayersPersistedState.textureSize ?? fallbackTextureSize

        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Texture size is below the minimum", bundle: .main) + ":\(textureSize.width) \(textureSize.height)"
            )
            Logger.error(error)
            throw error
        }

        removeAll()

        let layer = TextureLayerModel(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )

        textures[layer.id] = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )

        // Set the texture size after the initialization of this repository is completed
        _textureSize = textureSize

        let configuration: TextureLayersPersistedState = .init(
            layers: [layer],
            textureSize: textureSize
        )

        return try await .init(
            textureLayersPersistedState: textureLayersPersistedState,
            resolvedTextureSize: textureSize
        )
    }

    public func restoreStorage(
        from sourceFolderURL: URL,
        textureLayersPersistedState: TextureLayersPersistedState,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayersPersistedState {
        guard FileManager.containsAllFileNames(
            fileNames: textureLayersPersistedState.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        let textureSize = textureLayersPersistedState.textureSize ?? fallbackTextureSize

        // Temporary dictionary to hold new textures before applying
        var newTextures: [LayerId: MTLTexture] = [:]

        try textureLayersPersistedState.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
            )

            guard let hexadecimalData = textureData.encodedHexadecimals else {
                let error = NSError(
                    title: String(localized: "Error", bundle: .module),
                    message: String(localized: "Unable to load required data", bundle: .module)
                )
                Logger.error(error)
                throw error
            }

            guard
                let newTexture = try MTLTextureCreator.makeTexture(
                    width: Int(textureSize.width),
                    height: Int(textureSize.height),
                    from: hexadecimalData,
                    with: renderer.device
                )
            else {
                let error = NSError(
                    title: String(localized: "Error", bundle: .module),
                    message: String(localized: "Unable to load required data", bundle: .module)
                )
                Logger.error(error)
                throw error
            }

            newTextures[layer.id] = newTexture
        }

        textures = newTextures
        _textureSize = textureSize

        return try await .init(
            textureLayersPersistedState: textureLayersPersistedState,
            resolvedTextureSize: textureSize
        )
    }

    /// Returns the texture associated with the specified `LayerId`
    public func texture(id: LayerId) -> MTLTexture? {
        textures[id] as? MTLTexture
    }

    /// Removes all textures
    public func removeAll() {
        textures = [:]
    }

    /// Removes the texture for the specified `LayerId`
    public func removeTexture(_ id: LayerId) throws {
        // If the file exists, delete it
        guard textures.keys.contains(id) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to find \(id.uuidString)", bundle: .module)
            )
            throw error
        }
        textures.removeValue(forKey: id)
    }

    /// Adds a texture.Since `MTLTexture` is a reference type, this texture must be a new instance
    public func addTexture(newTexture: MTLTexture, id: LayerId) throws {
        // If it doesn’t exist, add it
        guard textures[id] == nil else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "File already exists", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
        textures[id] = newTexture
    }

    /// Updates the texture. Since `MTLTexture` is a reference type, this texture must be a new instance
    public func updateTexture(newTexture: MTLTexture, for id: LayerId) async throws {
        guard self.textures[id] != nil else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: "\(String(localized: "File not found", bundle: .module)):\(id.uuidString)"
            )
            Logger.error(error)
            throw error
        }
        textures[id] = newTexture
    }
}
