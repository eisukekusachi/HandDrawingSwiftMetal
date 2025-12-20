//
//  TextureInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import MetalKit
import SwiftUI

/// A repository that manages in-memory textures
@MainActor
public final class TextureInMemoryRepository {

    public var textureSize: CGSize {
        _textureSize
    }

    public var isInitialized: Bool {
        _textureSize != .zero
    }

    /// A dictionary with `LayerId` as the key and MTLTexture as the value
    private(set) var textures: [LayerId: MTLTexture?] = [:]

    private let renderer: MTLRendering

    private var cancellables = Set<AnyCancellable>()

    private var _textureSize: CGSize = .zero

    public init(
        textures: [LayerId: MTLTexture?] = [:],
        renderer: MTLRendering
    ) {
        self.textures = textures
        self.renderer = renderer
    }

    public func initializeStorage(
        configuration: TextureLayerArrayConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {
        let textureSize = configuration.textureSize ?? fallbackTextureSize

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
        setTextureSize(textureSize)

        let configuration: TextureLayerArrayConfiguration = .init(textureSize: textureSize, layers: [layer])

        return try await .init(
            configuration: configuration,
            resolvedTextureSize: textureSize
        )
    }

    public func restoreStorage(
        from sourceFolderURL: URL,
        configuration: TextureLayerArrayConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {
        guard FileManager.containsAllFileNames(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        let textureSize = configuration.textureSize ?? fallbackTextureSize

        // Temporary dictionary to hold new textures before applying
        var newTextures: [LayerId: MTLTexture] = [:]

        try configuration.layers.forEach { layer in
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

        removeAll()

        textures = newTextures
        setTextureSize(textureSize)

        return try await .init(
            configuration: configuration,
            resolvedTextureSize: textureSize
        )
    }

    /// Removes all textures
    public func removeAll() {
        textures = [:]
    }

    /// Removes a texture with `LayerId`
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

    /// Copies a texture for the given `LayerId`
    public func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture {
        guard
            let texture = textures[id],
            let texture,
            let newTexture = try await MTLTextureCreator.duplicateTexture(
                texture: texture,
                renderer: renderer
            )
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        return .init(id: id, texture: newTexture)
    }

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

    private func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }
}
