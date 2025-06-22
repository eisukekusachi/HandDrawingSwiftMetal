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
class TextureInMemoryRepository: ObservableObject, TextureRepository {

    /// A dictionary with UUID as the key and MTLTexture as the value
    var textures: [UUID: MTLTexture?] = [:]

    var textureNum: Int {
        textures.count
    }
    var textureSize: CGSize {
        _textureSize
    }

    var isInitialized: Bool {
        _textureSize != .zero
    }

    private let flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device = MTLCreateSystemDefaultDevice()!

    private var cancellables = Set<AnyCancellable>()

    private var _textureSize: CGSize = .zero

    init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.textures = textures
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, any Error> {
        initializeStorageWithNewTexture(configuration.textureSize ?? .zero)
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Future<CanvasConfiguration, Error> { [weak self] promise in
            guard let self else { return }

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
                        with: self.device
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

    func addTexture(_ texture: (any MTLTexture)?, using uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, any Error> {
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
            promise(.success(.init(uuid: uuid, texture: texture)))
        }
        .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, Error> {
        Future<TextureRepositoryEntity, Error> { [weak self] promise in
            guard let texture = self?.textures[uuid], let device = self?.device else {
                promise(.failure(TextureRepositoryError.failedToLoadTexture))
                return
            }
            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            )
            promise(.success(.init(uuid: uuid, texture: newTexture)))
        }
        .eraseToAnyPublisher()
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[TextureRepositoryEntity], Error> {
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

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
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

            promise(.success(uuid))
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
            title: TimeStampFormatter.currentDate()
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
            guard let `self` else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            self.textures[uuid] = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device)

            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

}
