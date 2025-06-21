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

    /// Attempts to restore layers from a given `CanvasConfiguration`
    /// If that is invalid, creates a new texture and initializes the canvas with it
    func initialize(from configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, any Error> {
        initializeStorage(configuration: configuration)
            .catch { [weak self] error -> AnyPublisher<CanvasConfiguration, Error> in
                guard let self else {
                    return Fail(error: TextureRepositoryError.failedToUnwrap).eraseToAnyPublisher()
                }
                return self.initializeStorageWithNewTexture(configuration.textureSize ?? .zero)
            }
            .eraseToAnyPublisher()
    }

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        isStorageSynchronized(with: configuration.layers.map { $0.fileName })
            .tryMap { [weak self] allExist in
                guard let self else {
                    throw TextureRepositoryError.failedToUnwrap
                }

                guard allExist else {
                    throw TextureRepositoryError.storageNotSynchronized
                }

                // Set the texture size after the initialization of this repository is completed
                self.setTextureSize(configuration.textureSize ?? .zero)

                return configuration
            }
            .eraseToAnyPublisher()
    }

    func initializeStorage(configuration: CanvasConfiguration, from sourceURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Future<CanvasConfiguration, Error> { [weak self] promise in
            guard let `self` else { return }

            // Delete all data
            self.removeAll()

            do {
                try configuration.layers.forEach { [weak self] layer in
                    let textureData = try Data(
                        contentsOf: sourceURL.appendingPathComponent(layer.id.uuidString)
                    )

                    guard
                        let device = self?.device,
                        let textureSize = configuration.textureSize,
                        let hexadecimalData = textureData.encodedHexadecimals
                    else { return }

                    let texture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: device
                    )

                    self?.textures[layer.id] = texture
                }

                // Set the texture size after the initialization of this repository is completed
                self.setTextureSize(textureSize)

                promise(.success(configuration))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) -> AnyPublisher<CanvasConfiguration, Error> {
        guard textureSize > MTLRenderer.minimumTextureSize else {
            Logger.standard.error("The texture size is too small")
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

            return ( .init(textureSize: textureSize, layers: [layer]))
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

    /// Checks whether the current storage directory contains the given set of file names
    private func isStorageSynchronized(with fileNames: [String]) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let `self` else { return }

            let hasAllTextures = fileNames.compactMap{ UUID(uuidString: $0) }.allSatisfy { self.textures[$0] != nil }

            promise(.success(
                !fileNames.isEmpty &&
                hasAllTextures &&
                Set(self.textures.keys.compactMap{ $0.uuidString }) == Set(fileNames))
            )
        }
        .eraseToAnyPublisher()
    }

}
