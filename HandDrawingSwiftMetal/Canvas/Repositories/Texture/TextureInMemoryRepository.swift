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
class TextureInMemoryRepository: TextureRepository {

    /// A dictionary with UUID as the key and MTLTexture as the value
    var textures: [UUID: MTLTexture?] = [:]

    var textureNum: Int {
        textures.count
    }
    var textureIds: Set<UUID> {
        Set(textures.keys.map { $0 })
    }
    var textureSize: CGSize {
        _textureSize
    }

    var isInitialized: Bool {
        _textureSize != .zero
    }

    private let renderer: MTLRendering!

    private var cancellables = Set<AnyCancellable>()

    private var _textureSize: CGSize = .zero

    init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.textures = textures
        self.renderer = renderer
    }

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        initializeStorageWithNewTexture(configuration.textureSize ?? .zero)
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Future<CanvasConfiguration, Error> { [weak self] promise in
            guard
                let self,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
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

                // If all succeeded, apply the new state
                self.removeAll()

                self.textures = newTextures
                self.setTextureSize(textureSize)

                promise(.success(configuration))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
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

            promise(.success(
                .init(uuid: uuid, texture: texture)
            ))
        }
        .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        Future<IdentifiedTexture, Error> { [weak self] promise in
            guard
                let texture = self?.textures[uuid],
                let device = MTLCreateSystemDefaultDevice()
            else {
                promise(.failure(TextureRepositoryError.failedToLoadTexture))
                return
            }

            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            )

            promise(.success(
                .init(uuid: uuid, texture: newTexture)
            ))
        }
        .eraseToAnyPublisher()
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[IdentifiedTexture], Error> {
        Publishers.MergeMany(
            uuids.map { copyTexture(uuid: $0) }
        )
        .collect()
        .eraseToAnyPublisher()
    }

    /// Clears texture ID data and the thumbnails
    func removeAll() {
        textures = [:]
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        textures.removeValue(forKey: uuid)
        return Just(uuid).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let texture,
                let device = MTLCreateSystemDefaultDevice()
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            guard self.textures[uuid] != nil else {
                promise(.failure(TextureRepositoryError.fileNotFound(uuid.uuidString)))
                return
            }

            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            )
            self.textures[uuid] = newTexture

            promise(.success(
                .init(uuid: uuid, texture: newTexture)
            ))
        }
        .eraseToAnyPublisher()
    }

}

extension TextureInMemoryRepository {

    private func initializeStorageWithNewTexture(_ textureSize: CGSize) -> AnyPublisher<CanvasConfiguration, Error> {
        guard
            Int(textureSize.width) > MTLRenderer.threadGroupLength &&
            Int(textureSize.height) > MTLRenderer.threadGroupLength
        else {
            Logger.standard.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return Fail(error: TextureRepositoryError.invalidTextureSize)
                .eraseToAnyPublisher()
        }

        // Delete all files
        self.removeAll()

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate
        )

        return createTexture(
            uuid: layer.id,
            textureSize: textureSize
        )
        .map { [weak self] _ in
            // Set the texture size after the initialization of this repository is completed
            self?.setTextureSize(textureSize)

            return .init(textureSize: textureSize, layers: [layer])
        }
        .eraseToAnyPublisher()
    }

    private func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            self.textures[uuid] = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)

            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

}
