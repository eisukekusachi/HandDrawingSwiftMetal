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

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        let textureSize = configuration.textureSize ?? .zero

        guard
            Int(textureSize.width) > MTLRenderer.threadGroupLength &&
            Int(textureSize.height) > MTLRenderer.threadGroupLength
        else {
            Logger.standard.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return Fail(error: TextureRepositoryError.invalidTextureSize)
                .eraseToAnyPublisher()
        }

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

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
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

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
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

    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        Future<IdentifiedTexture, Error> { [weak self] promise in
            guard
                let texture = self?.textures[uuid],
                let device = MTLCreateSystemDefaultDevice(),
                let newTexture = MTLTextureCreator.duplicateTexture(
                    texture: texture,
                    with: device
                )
            else {
                promise(.failure(TextureRepositoryError.failedToLoadTexture))
                return
            }

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

    /// Removes all textures
    func removeAll() {
        textures = [:]
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        textures.removeValue(forKey: uuid)
        return Just(uuid).setFailureType(to: Error.self).eraseToAnyPublisher()
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
