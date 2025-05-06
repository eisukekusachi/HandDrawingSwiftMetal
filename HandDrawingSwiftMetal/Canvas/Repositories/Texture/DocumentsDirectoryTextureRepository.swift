//
//  DocumentsDirectoryTextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import MetalKit
import SwiftUI

final class DocumentsDirectoryTextureRepository: ObservableObject {

    private(set) var textures: [UUID] = []
    @Published private(set) var thumbnails: [UUID: UIImage?] = [:]

    private static let storageName = "TextureStorage"

    // Define it as var to allow modification of its metadata
    private var directoryUrl = URL.applicationSupport.appendingPathComponent(DocumentsDirectoryTextureRepository.storageName)

    private let storageInitializationWithNewTextureSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let canvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private let needsThumbnailUpdateSubject: PassthroughSubject<UUID, Never> = .init()

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

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.createDirectory(&directoryUrl)
    }

}

extension DocumentsDirectoryTextureRepository: TextureRepository {

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }

    var canvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        canvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
    }

    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateSubject.eraseToAnyPublisher()
    }

    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.eraseToAnyPublisher()
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
                    // ids are retained if texture filenames in the directory match the ids of the configuration.layers
                    self.textures = configuration.layers.map { $0.id }

                    self.canvasInitializationUsingConfigurationSubject.send(configuration)
                } else {
                    self.storageInitializationWithNewTextureSubject.send(configuration)
                }
            })
            .store(in: &cancellables)
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {
        guard textureSize > MTLRenderer.minimumTextureSize else {
            Logger.standard.error("Failed to initialize canvas in DocumentsDirectoryTextureRepository: texture size is too small")
            return
        }

        // Delete all files
        resetDirectory(&directoryUrl)

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

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else { return }

            do {
                if let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device) {

                    try FileOutputManager.saveTextureAsData(
                        bytes: texture.bytes,
                        to: directoryUrl.appendingPathComponent(uuid.uuidString)
                    )

                    self.textures.append(uuid)
                    self.setThumbnail(texture: texture, for: uuid)

                    promise(.success(()))
                } else {
                    promise(.failure(TextureRepositoryError.failedToUnwrap))
                }

            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let `self` else { return }

            let fileURLs: [URL] = (try? FileManager.default.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil)) ?? []

            promise(
                .success(
                    !fileNames.isEmpty &&
                    Set(fileURLs.map { $0.lastPathComponent }) == Set(fileNames)
                )
            )
        }
        .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error> {
        Future<MTLTexture?, Error> { [weak self] promise in
            guard let `self` else { return }

            let destinationUrl = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            do {
                let texture: MTLTexture? = try FileInputManager.loadTexture(
                    url: destinationUrl,
                    textureSize: textureSize,
                    device: self.device
                )
                promise(
                    .success(
                        texture
                    )
                )
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID: MTLTexture?], Error> {
        let publishers = uuids.map { uuid in
            Future<(UUID, MTLTexture?), Error> { [weak self] promise in
                guard let `self` else { return }

                let destinationUrl = self.directoryUrl.appendingPathComponent(uuid.uuidString)

                do {
                    let texture: MTLTexture? = try FileInputManager.loadTexture(
                        url: destinationUrl,
                        textureSize: textureSize,
                        device: self.device
                    )
                    promise(
                        .success(
                            (uuid, texture)
                        )
                    )
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

    func loadNewTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else { return }

            // Delete all files
            self.resetDirectory(&self.directoryUrl)

            do {
                try uuids.forEach { uuid in
                    let textureData = try Data(
                        contentsOf: sourceURL.appendingPathComponent(uuid.uuidString)
                    )

                    if let hexadecimalData = textureData.encodedHexadecimals,
                       let texture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: self.device
                       ) {
                        try FileOutputManager.saveTextureAsData(
                            bytes: texture.bytes,
                            to: self.directoryUrl.appendingPathComponent(uuid.uuidString)
                        )

                        self.textures.append(uuid)
                        self.setThumbnail(texture: texture, for: uuid)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
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
        guard let texture else {
            Logger.standard.warning("Failed to create thumbnail for \(uuid)")
            return
        }
        thumbnails[uuid] = texture.makeThumbnail()
        needsThumbnailUpdateSubject.send(uuid)
    }

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let texture
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            do {
                let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

                try FileOutputManager.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )
                self.setThumbnail(texture: texture, for: uuid)

                promise(.success(uuid))
            } catch {
                Logger.standard.warning("Failed to save texture for UUID \(uuid): \(error)")
                promise(.failure(FileOutputError.failedToUpdateTexture))
            }
        }
        .eraseToAnyPublisher()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let `self` else { return }

            do {
                for textureId in self.textures {
                    let texture: MTLTexture? = try FileInputManager.loadTexture(
                        url: self.directoryUrl.appendingPathComponent(textureId.uuidString),
                        textureSize: textureSize,
                        device: self.device
                    )
                    self.setThumbnail(texture: texture, for: textureId)
                }

                promise(.success(()))

            } catch {
                Logger.standard.error("Failed to load texture during thumbnail update: \(error)")
                promise(.failure(FileOutputError.failedToUpdateTexture))
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

extension DocumentsDirectoryTextureRepository {
    // If a directory with the same name already exists at url,
    // this method does nothing and does not throw an error
    private func createDirectory(_ url: inout URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)

        } catch {
            Logger.standard.error("Failed to create texture storage directory: \(error)")
        }
    }

    // If the directory already exists, delete it and create a new one
    private func resetDirectory(_ url: inout URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            createDirectory(&url)

        } catch {
            Logger.standard.error("Failed to reset texture storage directory: \(error)")
        }
    }

}
