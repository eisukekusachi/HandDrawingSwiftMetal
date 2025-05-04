//
//  DocumentsFolderTextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import MetalKit
import SwiftUI

final class DocumentsFolderTextureRepository: ObservableObject {

    var drawableTextureSize: CGSize = MTLRenderer.minimumTextureSize {
        didSet {
            if drawableTextureSize < MTLRenderer.minimumTextureSize {
                drawableTextureSize = MTLRenderer.minimumTextureSize
            }
        }
    }

    private(set) var textures: [UUID] = []
    @Published private(set) var thumbnails: [UUID: UIImage?] = [:]

    private let needsCanvasInitializationAfterNewTextureCreationSubject = PassthroughSubject<CGSize, Never>()

    private let needsCanvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private let needsThumbnailUpdateSubject: PassthroughSubject<UUID, Never> = .init()

    private var _textureSize: CGSize = .zero

    private let directoryUrl = URL.documents.appendingPathComponent("Canvas")

    private let flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device = MTLCreateSystemDefaultDevice()!

    private var dataTask: Task<Void, Error>?

    private var cancellables = Set<AnyCancellable>()

    init(
        textures: [UUID] = [],
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

extension DocumentsFolderTextureRepository: TextureRepository {

    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> {
        needsCanvasInitializationAfterNewTextureCreationSubject.eraseToAnyPublisher()
    }
    var needsCanvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        needsCanvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
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
                    self.needsCanvasInitializationUsingConfigurationSubject.send(configuration)
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
            self?.needsCanvasInitializationUsingConfigurationSubject.send(
                .init(textureSize: textureSize, layers: [layer])
            )
        })
        .store(in: &cancellables)
    }

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            self.removeAll()

            let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device)

            self.textures.append(uuid)
            self.setThumbnail(texture: texture, for: uuid)

            self._textureSize = textureSize

            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error> {
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

                    self?.textures.append(layer.id)
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

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let self else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let fileURLs: [URL] = (try? FileManager.default.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil)) ?? []

            promise(
                .success(
                    !uuids.isEmpty &&
                    Set(fileURLs.map { $0.lastPathComponent }) == Set(uuids.map { $0.uuidString })
                )
            )
        }
        .eraseToAnyPublisher()
    }

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else { return }

            do {
                try FileOutputManager.createDirectory(self.directoryUrl)

                try layers.forEach { [weak self] layer in
                    guard let `self` else { return }

                    let fileUrl = folderURL.appendingPathComponent(layer.id.uuidString)
                    let destinationUrl = directoryUrl.appendingPathComponent(layer.id.uuidString)

                    let textureData = try Data(contentsOf: fileUrl)

                    guard
                        let hexadecimalData = textureData.encodedHexadecimals
                    else { return }

                    try FileManager.moveFile(source: fileUrl, destination: destinationUrl)

                    let texture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: self.device
                    )

                    self._textureSize = textureSize
                    self.textures.append(layer.id)
                    self.setThumbnail(texture: texture, for: layer.id)
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
        Future<MTLTexture?, Error> { promise in
            let destinationUrl = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            do {
                let texture: MTLTexture? = try FileInputManager.loadTexture(
                    destinationUrl,
                    textureSize: self.textureSize,
                    device: self.device
                )
                promise(.success(texture))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID: MTLTexture?], Error> {
        let publishers = uuids.map { uuid in
            Future<(UUID, MTLTexture?), Error> { promise in
                let destinationUrl = self.directoryUrl.appendingPathComponent(uuid.uuidString)

                do {
                    let texture: MTLTexture? = try FileInputManager.loadTexture(
                        destinationUrl,
                        textureSize: self.textureSize,
                        device: self.device
                    )
                    promise(.success((uuid, texture)))
                } catch {
                    promise(.failure(error))
                }
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
        Future { [weak self] promise in
            guard let `self` else { return }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }

            promise(.success(uuid))
        }
        .eraseToAnyPublisher()
    }
    func removeAll() {
        try? FileManager.clearContents(of: directoryUrl)
        thumbnails = [:]
    }

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        thumbnails[uuid] = texture?.makeThumbnail()

        objectWillChange.send()
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TextureRepositoryError.failedToAddTexture))
                return
            }

            guard let texture else {
                promise(.failure(TextureRepositoryError.failedToAddTexture))
                return
            }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            do {
                try FileOutputManager.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )
                self.setThumbnail(texture: texture, for: uuid)
                promise(.success(uuid))
            } catch {
                promise(.failure(FileOutputError.failedToUpdateTexture))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateTextureInStorage(texture: MTLTexture, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        loadTexture(uuid)
            .tryMap { [weak self] targetTexture in
                guard
                    let `self`
                else {
                    throw TextureRepositoryError.failedToUpdateTexture
                }

                let fileURL = directoryUrl.appendingPathComponent(uuid.uuidString)

                do {
                    try FileOutputManager.saveTextureAsData(
                        bytes: texture.bytes,
                        to: fileURL
                    )
                } catch {
                    throw FileOutputError.failedToUpdateTexture
                }

                return uuid
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
