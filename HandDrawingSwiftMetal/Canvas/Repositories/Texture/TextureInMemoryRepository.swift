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

    private let needsCanvasInitializationAfterNewTextureCreationSubject = PassthroughSubject<CGSize, Never>()

    private let needsCanvasRestorationFromConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private let needsThumbnailUpdateSubject: PassthroughSubject<UUID, Never> = .init()

    private var _textureSize: CGSize = .zero

    var drawableTextureSize: CGSize = MTLRenderer.minimumTextureSize {
        didSet {
            if drawableTextureSize < MTLRenderer.minimumTextureSize {
                drawableTextureSize = MTLRenderer.minimumTextureSize
            }
        }
    }

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

    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> {
        needsCanvasInitializationAfterNewTextureCreationSubject.eraseToAnyPublisher()
    }
    var needsCanvasRestorationFromConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        needsCanvasRestorationFromConfigurationSubject.eraseToAnyPublisher()
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
    var textureSize: CGSize {
        _textureSize
    }

    /// Attempts to restore layers from a given `CanvasConfiguration`
    /// If that is invalid, creates a new texture and initializes the canvas with it
    func resolveCanvasView(from configuration: CanvasConfiguration, drawableSize: CGSize) {
        drawableTextureSize = drawableSize

        hasAllTextures(for: configuration.layers.map { $0.id })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] allExist in
                guard let `self` else { return }

                if allExist {
                    self.needsCanvasRestorationFromConfigurationSubject.send(configuration)
                } else {
                    self.needsCanvasInitializationAfterNewTextureCreationSubject.send(
                        configuration.getTextureSize(drawableTextureSize: self.drawableTextureSize)
                    )
                }
            })
            .store(in: &cancellables)
    }

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize) {
        guard textureSize > MTLRenderer.minimumTextureSize else { return }

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate()
        )

        initializeTexture(
            uuid: layer.id,
            textureSize: textureSize
        )
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished: break
            case .failure: break
            }
        }, receiveValue: { [weak self] in
            self?.needsCanvasRestorationFromConfigurationSubject.send(
                .init(textureSize: textureSize, layers: [layer])
            )
        })
        .store(in: &cancellables)
    }

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let self else {
                promise(.failure(TextureRepositoryError.repositoryDeinitialized))
                return
            }

            let hasAllTextures = uuids.allSatisfy { self.textures[$0] != nil }

            promise(.success(
                !uuids.isEmpty &&
                hasAllTextures &&
                Set(self.textures.keys) == Set(uuids))
            )
        }
        .eraseToAnyPublisher()
    }

    func initializeTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            self.removeAll()

            let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device)

            self.textures[uuid] = texture
            self.setThumbnail(texture: texture, for: uuid)

            self._textureSize = textureSize

            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

    func initializeTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
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

                    self?._textureSize = textureSize
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<MTLTexture?, Error> {
        Future<MTLTexture?, Error> { [weak self] promise in
            guard let texture = self?.textures[uuid] else {
                promise(.failure(TextureRepositoryError.failedToLoadTexture))
                return
            }
            promise(.success(texture))
        }
        .eraseToAnyPublisher()
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID: MTLTexture?], Error> {
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

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        textures.removeValue(forKey: uuid)
        thumbnails.removeValue(forKey: uuid)
        return Just(uuid).eraseToAnyPublisher()
    }
    func removeAll() {
        textures = [:]
        thumbnails = [:]
    }

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        thumbnails[uuid] = texture?.makeThumbnail()
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

    func updateCanvasAfterTextureLayerUpdates() {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.send()
    }

    func updateCanvas() {
        needsCanvasUpdateSubject.send()
    }

}
