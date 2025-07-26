//
//  TextureLayerInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import MetalKit
import SwiftUI

/// A repository that manages in-memory textures and thumbnails
final class TextureLayerInMemoryRepository: TextureInMemoryRepository, TextureLayerRepository {

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

    override func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        guard FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            return Fail(error: TextureRepositoryError.invalidValue("restoreStorage(from:, with:)")).eraseToAnyPublisher()
        }

        return Future<CanvasConfiguration, Error> { [weak self] promise in
            guard
                let self,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
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

                self.removeAll()

                self.textures = newTextures
                self.thumbnails = newThumbnails

                self.setTextureSize(textureSize)

                promise(.success(configuration))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    override func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
            self.textures[uuid] = texture
            self.setThumbnail(texture: texture, for: uuid)

            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

    override func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, any Error> {
        Future { [weak self] promise in
            guard let `self`, let texture else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            guard self.textures[uuid] == nil else {
                promise(.failure(TextureRepositoryError.fileAlreadyExists))
                return
            }

            self.textures[uuid] = texture
            self.setThumbnail(texture: texture, for: uuid)

            promise(.success(
                .init(uuid: uuid, texture: texture)
            ))
        }
        .eraseToAnyPublisher()
    }

    override func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        textures.removeValue(forKey: uuid)
        thumbnails.removeValue(forKey: uuid)
        return Just(uuid).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    @discardableResult override func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
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
