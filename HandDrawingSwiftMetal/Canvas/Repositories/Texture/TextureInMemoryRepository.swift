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

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }

    var storageInitializationCompletedPublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationCompletedSubject.eraseToAnyPublisher()
    }

    var textureNum: Int {
        textures.count
    }
    var textureSize: CGSize {
        _textureSize
    }

    var isInitialized: Bool {
        _textureSize != .zero
    }

    private let storageInitializationWithNewTextureSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let storageInitializationCompletedSubject = PassthroughSubject<CanvasConfiguration, Never>()

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
    func initializeStorage(from configuration: CanvasConfiguration) {
        hasAllTextures(fileNames: configuration.layers.map { $0.fileName })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] allExist in
                guard let `self` else { return }

                if allExist {
                    // Set `_textureSize` after the initialization of this repository is completed
                    self._textureSize = configuration.textureSize ?? .zero

                    self.storageInitializationCompletedSubject.send(configuration)
                } else {
                    self.storageInitializationWithNewTextureSubject.send(configuration)
                }
            })
            .store(in: &cancellables)
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {
        guard textureSize > MTLRenderer.minimumTextureSize else {
            Logger.standard.error("Failed to initialize canvas in TextureInMemoryRepository: texture size is too small")
            return
        }

        // Delete all files
        self.removeAll()

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate()
        )

        createTexture(
            uuid: layer.id,
            textureSize: textureSize
        )
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished: break
            case .failure: break
            }
        }, receiveValue: { [weak self] in
            // Set `_textureSize` after the initialization of this repository is completed
            self?._textureSize = textureSize

            self?.storageInitializationCompletedSubject.send(
                .init(textureSize: textureSize, layers: [layer])
            )
        })
        .store(in: &cancellables)
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[TextureRepositoryEntity], Error> {
        let publishers = uuids.map { uuid in
            Future<TextureRepositoryEntity, Error> { [weak self] promise in
                guard let texture = self?.textures[uuid] else {
                    promise(.failure(TextureRepositoryError.failedToLoadTexture))
                    return
                }
                promise(.success(.init(uuid: uuid, texture: texture)))
            }
            .eraseToAnyPublisher()
        }

        return Publishers.MergeMany(publishers)
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

    func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            do {
                // Delete all data
                self?.removeAll()

                try uuids.forEach { [weak self] uuid in
                    let textureData = try Data(
                        contentsOf: sourceURL.appendingPathComponent(uuid.uuidString)
                    )

                    guard
                        let device = self?.device,
                        let hexadecimalData = textureData.encodedHexadecimals
                    else { return }

                    let texture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: device
                    )

                    self?.textures[uuid] = texture
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            if let texture, let device = self?.device {
                let newTexture = MTLTextureCreator.duplicateTexture(
                    texture: texture,
                    with: device
                )
                self?.textures[uuid] = newTexture

                promise(.success(uuid))
            } else {
                promise(.failure(TextureRepositoryError.failedToAddTexture))
            }
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

    private func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, Error> {
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
