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

    /// A subject that emits when a new texture should be created and the canvas initialized.
    private let initializeCanvasAfterCreatingNewTextureSubject = PassthroughSubject<CGSize, Never>()

    /// A subject that emits when the canvas should be restored from a model.
    private let restoreCanvasFromModelSubject = PassthroughSubject<CanvasModel, Never>()

    /// A subject that emits after texture layers have been updated to refresh the canvas.
    private let updateCanvasAfterTextureLayerUpdatesSubject = PassthroughSubject<Void, Never>()

    /// A subject that emits to trigger a full canvas update.
    private let updateCanvasSubject = PassthroughSubject<Void, Never>()

    /// A subject that notifies SwiftUI about a thumbnail update for a specific layer.
    private let thumbnailWillChangeSubject: PassthroughSubject<UUID, Never> = .init()

    private var _textureSize: CGSize?

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

    var initializeCanvasAfterCreatingNewTexturePublisher: AnyPublisher<CGSize, Never> {
        initializeCanvasAfterCreatingNewTextureSubject.eraseToAnyPublisher()
    }
    var restoreCanvasFromModelPublisher: AnyPublisher<CanvasModel, Never> {
        restoreCanvasFromModelSubject.eraseToAnyPublisher()
    }

    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> {
        updateCanvasAfterTextureLayerUpdatesSubject.eraseToAnyPublisher()
    }
    var updateCanvasPublisher: AnyPublisher<Void, Never> {
        updateCanvasSubject.eraseToAnyPublisher()
    }

    var thumbnailWillChangePublisher: AnyPublisher<UUID, Never> {
        thumbnailWillChangeSubject.eraseToAnyPublisher()
    }

    var textureNum: Int {
        thumbnails.count
    }
    var textureSize: CGSize {
        _textureSize ?? .zero
    }

    /// Attempts to restore layers from a given `CanvasModel`
    /// If the model is invalid, initialization is performed using the given texture size
    func resolveCanvasView(from model: CanvasModel, drawableSize: CGSize) {
        drawableTextureSize = drawableSize

        hasAllTextures(for: model.layers.map { $0.id })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] allExist in
                guard let `self` else { return }

                if allExist {
                    self.restoreCanvasFromModelSubject.send(model)
                } else {
                    self.initializeCanvasAfterCreatingNewTextureSubject.send(
                        model.getTextureSize(drawableTextureSize: self.drawableTextureSize)
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

        initTexture(
            uuid: layer.id,
            textureSize: textureSize
        )
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished: break
            case .failure: break
            }
        }, receiveValue: { [weak self] in
            self?.restoreCanvasFromModelSubject.send(
                CanvasModel(textureSize: textureSize, layers: [layer])
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

    private func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
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

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
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
        thumbnailWillChangeSubject.send(uuid)
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
        updateCanvasAfterTextureLayerUpdatesSubject.send()
    }

    func updateCanvas() {
        updateCanvasSubject.send()
    }


}
