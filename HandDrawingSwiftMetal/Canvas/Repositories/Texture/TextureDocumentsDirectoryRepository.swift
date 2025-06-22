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

    var textureNum: Int {
        textureIds.count
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
        targetURL: URL,
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
        self.directoryUrl = targetURL.appendingPathComponent(directoryName)

        self.createDirectory(&directoryUrl)
    }

    /// Attempts to restore layers from a given `CanvasConfiguration`
    /// If that is invalid, creates a new texture and initializes the canvas with it
    func initialize(from configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
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
        isStorageSynchronized(at: directoryUrl, expectedFileNames: configuration.layers.map { $0.fileName })
            .tryMap { [weak self] allExist in
                guard let self else {
                    throw TextureRepositoryError.failedToUnwrap
                }

                guard allExist else {
                    throw TextureRepositoryError.storageNotSynchronized
                }

                // Retain IDs if texture filenames match the configuration
                self.textureIds = Set(configuration.layers.map { $0.id })

                // Set the texture size after the initialization of this repository is completed
                self.setTextureSize(configuration.textureSize ?? .zero)

                return (configuration)
            }
            .eraseToAnyPublisher()
    }

    func initializeStorage(configuration: CanvasConfiguration, from sourceURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Future<CanvasConfiguration, Error> { [weak self] promise in
            guard let `self` else { return }

            // Delete all files
            self.resetDirectory(&self.directoryUrl)

            do {
                try configuration.layers.forEach { [weak self] layer in
                    guard let `self` else { return }

                    let textureData = try Data(
                        contentsOf: sourceURL.appendingPathComponent(layer.id.uuidString)
                    )

                    guard
                        let hexadecimalData = textureData.encodedHexadecimals,
                        let newTexture = MTLTextureCreator.makeTexture(
                            size: textureSize,
                            colorArray: hexadecimalData,
                            with: self.device
                        )
                    else { return }

                    try FileOutputManager.saveTextureAsData(
                        bytes: newTexture.bytes,
                        to: self.directoryUrl.appendingPathComponent(layer.id.uuidString)
                    )

                    self.textureIds.insert(layer.id)
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
            Logger.standard.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return Fail(error: TextureRepositoryError.invalidTextureSize).eraseToAnyPublisher()
        }

        // Delete all files in the directory
        resetDirectory(&directoryUrl)

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

            return (.init(textureSize: textureSize, layers: [layer]))
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

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            guard !FileManager.default.fileExists(atPath: fileURL.path) else {
                promise(.failure(TextureRepositoryError.fileAlreadyExists))
                return
            }

            do {
                try FileOutputManager.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )

                promise(.success(.init(uuid: uuid, texture: texture)))

            } catch {
                Logger.standard.warning("Failed to save texture for UUID \(uuid): \(error)")
                promise(.failure(FileOutputError.failedToUpdateTexture))
            }
        }
        .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, Error> {
        Future<TextureRepositoryEntity, Error> { [weak self] promise in
            guard let `self` else { return }

            let destinationUrl = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            do {
                let newTexture: MTLTexture? = try FileInputManager.loadTexture(
                    url: destinationUrl,
                    textureSize: self.textureSize,
                    device: self.device
                )
                promise(
                    .success(
                        .init(uuid: uuid, texture: newTexture)
                    )
                )
            } catch {
                promise(.failure(error))
            }
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

    /// Deletes all files within the directory and clears texture ID data
    func removeAll() {
        // Delete all contents inside the folder
        try? FileManager.clearContents(of: directoryUrl)

        // Clear the texture ID array
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

    /// Deletes the entire directory and recreates it as an empty folder
    func resetDirectory(_ url: inout URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            // Create a new folder
            createDirectory(&url)

            // Clear in-memory texture ID data
            textureIds = []

        } catch {
            Logger.standard.error("Failed to reset texture storage directory: \(error)")
        }
    }

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard let `self`, let texture
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                promise(.failure(TextureRepositoryError.fileNotFound))
                return
            }

            do {
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

    /// Checks whether the contents of the specified directory exactly match the given set of file names
    private func isStorageSynchronized(
        at directory: URL,
        expectedFileNames: [String]
    ) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { promise in
            let fileURLs: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []

            let existingFileNames = Set(fileURLs.map { $0.lastPathComponent })
            let expectedNames = Set(expectedFileNames)

            let isSynchronized = !expectedNames.isEmpty && existingFileNames == expectedNames

            promise(.success(isSynchronized))
        }
        .eraseToAnyPublisher()
    }
}
