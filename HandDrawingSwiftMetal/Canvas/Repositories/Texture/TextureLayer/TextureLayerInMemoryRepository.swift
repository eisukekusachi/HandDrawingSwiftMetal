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

    private(set) var thumbnails: [UUID: UIImage?] = [:]

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        objectWillChangeSubject.eraseToAnyPublisher()
    }
    private let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    private let device = MTLCreateSystemDefaultDevice()!

    override init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        super.init(textures: textures, renderer: renderer)
    }

    /// Clears texture ID data and the thumbnails
    override func removeAll() {
        textures = [:]
        thumbnails = [:]
    }

    override func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Future<CanvasConfiguration, Error> { [weak self] promise in
            guard let self else { return }

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
                        throw TextureRepositoryError.failedToLoadTexture
                    }

                    guard let newTexture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: self.device
                    ) else {
                        throw TextureRepositoryError.failedToLoadTexture
                    }

                    newTextures[layer.id] = newTexture
                    newThumbnails[layer.id] = newTexture.makeThumbnail()
                }

                // If all succeeded, apply the new state
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

    override func addTexture(_ texture: (any MTLTexture)?, using uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, any Error> {
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

            promise(.success(.init(uuid: uuid, texture: texture)))
        }
        .eraseToAnyPublisher()
    }

    override func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        textures.removeValue(forKey: uuid)
        thumbnails.removeValue(forKey: uuid)
        return Just(uuid).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    override func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard let `self`, let texture else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            guard self.textures[uuid] != nil else {
                promise(.failure(TextureRepositoryError.fileNotFound))
                return
            }

            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: self.device
            )
            self.textures[uuid] = newTexture
            self.setThumbnail(texture: newTexture, for: uuid)

            promise(.success(uuid))
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerInMemoryRepository {

    func thumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future { promise in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let `self` else { return }

                for (uuid, texture) in self.textures {
                    guard let texture else { return }
                    self.setThumbnail(texture: texture, for: uuid)
                }

                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerInMemoryRepository {

    private func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        thumbnails[uuid] = texture?.makeThumbnail()
        objectWillChangeSubject.send(())
    }

}
