//
//  TextureLayerInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import MetalKit
import SwiftUI
@preconcurrency import Combine

/// A repository that manages in-memory textures and thumbnails
final class TextureLayerInMemoryRepository: TextureInMemoryRepository, TextureLayerRepository, @unchecked Sendable {

    let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    private(set) var thumbnails: [UUID: UIImage?] = [:]

    override init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        super.init(textures: textures, renderer: renderer)
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    /// Removes all textures and thumbnails
    override func removeAll() {
        textures = [:]
        thumbnails = [:]
    }

    override func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) async throws {
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
        var newThumbnails: [UUID: UIImage?] = [:]

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
            newThumbnails[layer.id] = newTexture.makeThumbnail()
        }

        removeAll()

        textures = newTextures
        thumbnails = newThumbnails

        setTextureSize(textureSize)
    }

    override func createTexture(uuid: UUID, textureSize: CGSize) async throws {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

        let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
        textures[uuid] = texture
        setThumbnail(texture: texture, for: uuid)
    }

    override func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        guard let texture else {
            throw TextureRepositoryError.failedToUnwrap
        }

        guard self.textures[uuid] == nil else {
            throw TextureRepositoryError.fileAlreadyExists
        }

        textures[uuid] = texture
        setThumbnail(texture: texture, for: uuid)

        return .init(uuid: uuid, texture: texture)
    }

    override func removeTexture(_ uuid: UUID) throws -> UUID {
        textures.removeValue(forKey: uuid)
        thumbnails.removeValue(forKey: uuid)
        return uuid
    }

    override func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let texture,
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

        guard self.textures[uuid] != nil else {
            throw TextureRepositoryError.fileNotFound(uuid.uuidString)
        }

        guard let newTexture = MTLTextureCreator.duplicateTexture(
            texture: texture,
            with: device
        ) else {
            throw TextureRepositoryError.failedToUnwrap
        }

        textures[uuid] = newTexture
        setThumbnail(texture: newTexture, for: uuid)

        return .init(uuid: uuid, texture: newTexture)
    }
}

extension TextureLayerInMemoryRepository {

    private func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        thumbnails[uuid] = texture?.makeThumbnail()
        objectWillChangeSubject.send(())
    }
}
