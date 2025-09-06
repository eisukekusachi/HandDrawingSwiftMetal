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
class TextureInMemoryRepository: TextureRepository {

    /// A dictionary with UUID as the key and MTLTexture as the value
    var textures: [UUID: MTLTexture?] = [:]

    var textureNum: Int {
        textures.count
    }

    /// IDs of the textures stored in the repository
    var textureIds: Set<UUID> {
        Set(textures.keys.map { $0 })
    }
    var textureSize: CGSize {
        _textureSize
    }

    var isInitialized: Bool {
        _textureSize != .zero
    }

    private let renderer: MTLRendering

    private var cancellables = Set<AnyCancellable>()

    private var _textureSize: CGSize = .zero

    init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: MTLRendering
    ) {
        self.textures = textures
        self.renderer = renderer
    }

    func initializeStorage(
        configuration: ProjectConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> CanvasResolvedConfiguration {
        let textureSize = configuration.textureSize ?? fallbackTextureSize

        guard
            Int(textureSize.width) > canvasMinimumTextureLength &&
            Int(textureSize.height) > canvasMinimumTextureLength
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
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )

        try await createTexture(
            uuid: layer.id,
            textureSize: textureSize
        )

        // Set the texture size after the initialization of this repository is completed
        setTextureSize(textureSize)

        let configuration: ProjectConfiguration = .init(textureSize: textureSize, layers: [layer])

        return try await .init(
            configuration: configuration,
            resolvedTextureSize: textureSize
        )
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: ProjectConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> CanvasResolvedConfiguration {
        guard FileManager.containsAll(
            fileNames: configuration.layers.map { $0.textureName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        guard
            let device = renderer.device
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        let textureSize = configuration.textureSize ?? defaultTextureSize

        // Temporary dictionary to hold new textures before applying
        var newTextures: [UUID: MTLTexture] = [:]

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

            guard let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                from: hexadecimalData,
                with: device
            ) else {
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

    func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {
        guard
            let device = renderer.device
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Missing required parameter", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        textures[uuid] = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )
    }

    /// Removes all textures
    func removeAll() {
        textures = [:]
    }

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> UUID {
        textures.removeValue(forKey: uuid)
        return uuid
    }

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let texture = textures[uuid],
            let newTexture = await renderer.duplicateTexture(
                texture: texture
            )
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        return .init(uuid: uuid, texture: newTexture)
    }

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) async throws -> [IdentifiedTexture] {
        try await withThrowingTaskGroup(of: IdentifiedTexture.self) { group in
            for id in uuids {
                group.addTask { try await self.copyTexture(uuid: id) }
            }

            var results: [IdentifiedTexture] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }


    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        guard let texture else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        guard textures[uuid] == nil else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "File already exists", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        textures[uuid] = texture

        return .init(uuid: uuid, texture: texture)
    }

    @discardableResult func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let texture,
            let newTexture = await renderer.duplicateTexture(texture: texture)
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        guard self.textures[uuid] != nil else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: "\(String(localized: "File not found", bundle: .module)):\(uuid.uuidString)"
            )
            Logger.error(error)
            throw error
        }

        textures[uuid] = newTexture

        return .init(uuid: uuid, texture: newTexture)
    }
}
