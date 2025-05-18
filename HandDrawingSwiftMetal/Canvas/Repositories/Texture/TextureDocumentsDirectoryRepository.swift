//
//  TextureDocumentsDirectoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import MetalKit
import SwiftUI

/// A repository that manages on-disk textures
class TextureDocumentsDirectoryRepository: ObservableObject, TextureRepository {

    /// The directory name where texture files are stored
    let directoryName: String

    /// The URL of the texture storage directory. Define it as `var` to allow modification of its metadata
    var directoryUrl: URL

    /// The IDs of the textures managed by this repository. The IDs are used as file names.
    var textureIds: Set<UUID> = []

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }

    var storageInitializationCompletedPublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationCompletedSubject.eraseToAnyPublisher()
    }

    var textureNum: Int {
        textureIds.count
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
        directoryName: String,
        textures: Set<UUID> = [],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.textureIds = textures
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.directoryName = directoryName
        self.directoryUrl = URL.applicationSupport.appendingPathComponent(directoryName)

        self.createDirectory(&directoryUrl)
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
                    self.textureIds = Set(configuration.layers.map { $0.id })

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
            Logger.standard.error("Failed to initialize canvas in TextureDocumentsDirectoryRepository: texture size is too small")
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
            // Set `_textureSize` after the initialization of this repository is completed
            self?._textureSize = textureSize

            self?.storageInitializationCompletedSubject.send(
                .init(textureSize: textureSize, layers: [layer])
            )
        })
        .store(in: &cancellables)
    }

    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<TextureRepositoryEntity, Error> {
        Future<TextureRepositoryEntity, Error> { [weak self] promise in
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
                        .init(uuid: uuid, texture: texture)
                    )
                )
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[TextureRepositoryEntity], Error> {
        let publishers = uuids.map { uuid in
            Future<TextureRepositoryEntity, Error> { [weak self] promise in
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
                            .init(uuid: uuid, texture: texture)
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
            .eraseToAnyPublisher()
    }

    func removeAll() {
        try? FileManager.clearContents(of: directoryUrl)
        textureIds = []
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard let `self` else { return }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }

            textureIds.remove(uuid)

            promise(.success(uuid))
        }
        .eraseToAnyPublisher()
    }

    func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
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

                        self.textureIds.insert(uuid)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
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

                promise(.success(uuid))
            } catch {
                Logger.standard.warning("Failed to save texture for UUID \(uuid): \(error)")
                promise(.failure(FileOutputError.failedToUpdateTexture))
            }
        }
        .eraseToAnyPublisher()
    }

    // If the directory already exists, delete it and create a new one
    func resetDirectory(_ url: inout URL) {
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

extension TextureDocumentsDirectoryRepository {
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

    private func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else { return }

            do {
                if let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device) {

                    try FileOutputManager.saveTextureAsData(
                        bytes: texture.bytes,
                        to: directoryUrl.appendingPathComponent(uuid.uuidString)
                    )

                    self.textureIds.insert(uuid)

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

    private func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, Error> {
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

}
