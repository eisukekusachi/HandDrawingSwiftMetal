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
class TextureInMemoryRepository: TextureRepository, @unchecked Sendable {

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
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.textures = textures
        self.renderer = renderer
    }

    func initializeStorage(configuration: CanvasConfiguration) async throws -> CanvasConfiguration {
        let textureSize = configuration.textureSize ?? .zero

        guard
            Int(textureSize.width) > MTLRenderer.threadGroupLength &&
            Int(textureSize.height) > MTLRenderer.threadGroupLength
        else {
            Logger.standard.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            throw TextureRepositoryError.invalidTextureSize
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

        return .init(textureSize: textureSize, layers: [layer])
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) async throws {
        guard FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            throw TextureRepositoryError.invalidValue("restoreStorage(from:, with:)")
        }

        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

        // Temporary dictionary to hold new textures before applying
        var newTextures: [UUID: MTLTexture] = [:]

        guard let textureSize = configuration.textureSize else {
            throw TextureRepositoryError.invalidTextureSize
        }

        try configuration.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
            )

            guard let hexadecimalData = textureData.encodedHexadecimals else {
                throw TextureRepositoryError.failedToUnwrap
            }

            guard let newTexture = MTLTextureCreator.makeTexture(
                size: textureSize,
                colorArray: hexadecimalData,
                with: device
            ) else {
                throw TextureRepositoryError.failedToLoadTexture
            }

            newTextures[layer.id] = newTexture
        }

        removeAll()

        textures = newTextures
        setTextureSize(textureSize)
    }

    func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

        textures[uuid] = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
    }

    /// Removes all textures
    func removeAll() {
        textures = [:]
    }

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) throws -> UUID {
        textures.removeValue(forKey: uuid)
        return uuid
    }

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let texture = textures[uuid],
            let device = MTLCreateSystemDefaultDevice(),
            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            )
        else {
            throw TextureRepositoryError.failedToLoadTexture
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
            throw TextureRepositoryError.failedToUnwrap
        }

        guard textures[uuid] == nil else {
            throw TextureRepositoryError.fileAlreadyExists
        }

        textures[uuid] = texture

        return .init(uuid: uuid, texture: texture)
    }

    @discardableResult func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let texture,
            let device = MTLCreateSystemDefaultDevice(),
            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            )
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

        guard self.textures[uuid] != nil else {
            throw TextureRepositoryError.fileNotFound(uuid.uuidString)
        }

        textures[uuid] = newTexture

        return .init(uuid: uuid, texture: newTexture)
    }
}
