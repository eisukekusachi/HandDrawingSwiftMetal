//
//  TextureInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import MetalKit
import SwiftUI

final class TextureInMemoryRepository: ObservableObject {

    private(set) var textures: [UUID: MTLTexture?] = [:]
    @Published private(set) var thumbnails: [UUID: UIImage?] = [:]

    private let storageInitializationWithNewTextureSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let canvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private let needsThumbnailUpdateSubject: PassthroughSubject<UUID, Never> = .init()

    private let flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device = MTLCreateSystemDefaultDevice()!

    private var cancellables = Set<AnyCancellable>()

    init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: (any MTLRendering) = MTLRenderer.shared
    ) {
        self.textures = textures
        self.renderer = renderer

        flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension TextureInMemoryRepository: TextureRepository {

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }

    var canvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        canvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
    }

    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.eraseToAnyPublisher()
    }
    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateSubject.eraseToAnyPublisher()
    }

    var needsThumbnailUpdatePublisher: AnyPublisher<UUID, Never> {
        needsThumbnailUpdateSubject.eraseToAnyPublisher()
    }

    var textureNum: Int {
        thumbnails.count
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
                    self.canvasInitializationUsingConfigurationSubject.send(configuration)
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
            self?.canvasInitializationUsingConfigurationSubject.send(
                .init(textureSize: textureSize, layers: [layer])
            )
        })
        .store(in: &cancellables)
    }

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, Error> {
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

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            self.removeAll()

            let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device)

            self.textures[uuid] = texture
            self.setThumbnail(texture: texture, for: uuid)

            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func loadTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error> {
        Future<MTLTexture?, Error> { [weak self] promise in
            guard let texture = self?.textures[uuid] else {
                promise(.failure(TextureRepositoryError.failedToLoadTexture))
                return
            }
            promise(.success(texture))
        }
        .eraseToAnyPublisher()
    }

    func loadTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID: MTLTexture?], Error> {
        let publishers = uuids.map { uuid in
            Future<(UUID, MTLTexture?), Error> { [weak self] promise in
                guard let texture = self?.textures[uuid] else {
                    promise(.failure(TextureRepositoryError.failedToLoadTexture))
                    return
                }
                promise(.success((uuid, texture)))
            }
            .eraseToAnyPublisher()
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { pairs in
                Dictionary(uniqueKeysWithValues: pairs)
            }
            .eraseToAnyPublisher()
    }

    func loadTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        Future<Void, Error> { [weak self] promise in
            do {
                self?.removeAll()

                try layers.forEach { [weak self] layer in
                    let textureData = try Data(
                        contentsOf: folderURL.appendingPathComponent(layer.id.uuidString)
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

                    self?.textures[layer.id] = texture
                    self?.setThumbnail(texture: texture, for: layer.id)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        textures.removeValue(forKey: uuid)
        thumbnails.removeValue(forKey: uuid)
        return Just(uuid).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func removeAll() {
        textures = [:]
        thumbnails = [:]
    }

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        guard let texture else {
            Logger.standard.warning("Failed to create thumbnail for \(uuid)")
            return
        }
        thumbnails[uuid] = texture.makeThumbnail()
        needsThumbnailUpdateSubject.send(uuid)
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            if let texture {
                self?.textures[uuid] = texture
                self?.setThumbnail(texture: texture, for: uuid)

                promise(.success(uuid))
            } else {
                promise(.failure(TextureRepositoryError.failedToAddTexture))
            }
        }
        .eraseToAnyPublisher()
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

    func updateCanvasAfterTextureLayerUpdates() {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.send()
    }

    func updateCanvas() {
        needsCanvasUpdateSubject.send()
    }

}
