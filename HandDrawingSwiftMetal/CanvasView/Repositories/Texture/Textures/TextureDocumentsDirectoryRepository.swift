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
class TextureDocumentsDirectoryRepository: TextureRepository {

    /// The directory name where texture files are stored
    let directoryName: String

    /// The URL of the texture storage. Define it as `var` to allow modification of its metadata
    private(set) var workingDirectoryURL: URL!

    /// IDs of the textures stored in the repository
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

    private let renderer: MTLRendering

    private var cancellables = Set<AnyCancellable>()

    private var _textureSize: CGSize = .zero

    init(
        storageDirectoryURL: URL,
        directoryName: String,
        textures: Set<UUID> = [],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.textureIds = textures
        self.renderer = renderer

        self.directoryName = directoryName

        self.workingDirectoryURL = storageDirectoryURL.appendingPathComponent(directoryName)

        // Do not back up because this is an intermediate directory
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try workingDirectoryURL.setResourceValues(resourceValues)
        } catch {
            Logger.standard.error("LocalFileRepository: \(error)")
        }

        do {
            try FileManager.createDirectory(workingDirectoryURL)
        } catch {
            Logger.standard.error("Failed to create the storage: \(error)")
        }
    }

    /// Attempts to restore the repository from a given `CanvasConfiguration`
    /// If that is invalid, creates a new texture and initializes the repository with it
    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        if FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(workingDirectoryURL)
        ) {
            // Retain IDs
            textureIds = Set(configuration.layers.map { $0.id })

            // Retain the texture size
            setTextureSize(configuration.textureSize ?? .zero)

            return Just(configuration)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return initializeStorageWithNewTexture(configuration.textureSize ?? .zero)
                .eraseToAnyPublisher()
        }
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
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
                var tmpTextureIds: Set<UUID> = []

                try configuration.layers.forEach { layer in
                    let textureData = try Data(
                        contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
                    )
                    guard
                        let textureSize = configuration.textureSize,
                        let hexadecimalData = textureData.encodedHexadecimals,
                        let _ = MTLTextureCreator.makeTexture(
                            size: textureSize,
                            colorArray: hexadecimalData,
                            with: device
                        )
                    else {
                        throw TextureRepositoryError.failedToUnwrap
                    }

                    tmpTextureIds.insert(layer.id)
                }

                // Delete all textures in the repository
                self.removeAll()

                // Move all files
                try configuration.layers.forEach { layer in
                    try FileManager.default.moveItem(
                        at: sourceFolderURL.appendingPathComponent(layer.id.uuidString),
                        to: self.workingDirectoryURL.appendingPathComponent(layer.id.uuidString)
                    )
                }

                self.textureIds = tmpTextureIds

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
        guard
            Int(textureSize.width) > MTLRenderer.threadGroupLength &&
                Int(textureSize.height) > MTLRenderer.threadGroupLength
        else {
            Logger.standard.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return Fail(error: TextureRepositoryError.invalidTextureSize).eraseToAnyPublisher()
        }

        // Delete all textures in the repository
        removeAll()

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

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
                if let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device) {
                    try FileOutput.saveTextureAsData(
                        bytes: texture.bytes,
                        to: workingDirectoryURL.appendingPathComponent(uuid.uuidString)
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

    func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        Future { [weak self] promise in
            guard let `self`, let texture else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let fileURL = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

            guard !FileManager.default.fileExists(atPath: fileURL.path) else {
                promise(.failure(TextureRepositoryError.fileAlreadyExists))
                return
            }

            do {
                try FileOutput.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )

                promise(.success(
                    .init(uuid: uuid, texture: texture)
                ))

            } catch {
                promise(.failure(TextureDocumentsDirectoryRepositoryError.failedToUpdateTexture(error)))
            }
        }
        .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        if textureSize == .zero {
            return Fail(
                error: TextureDocumentsDirectoryRepositoryError.textureSizeIsZero
            )
            .eraseToAnyPublisher()
        }

        let destinationUrl = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

        return Future<IdentifiedTexture, Error> { [weak self] promise in
            do {
                guard
                    let `self`,
                    let device = MTLCreateSystemDefaultDevice(),
                    let newTexture: MTLTexture = try FileInput.loadTexture(
                        url: destinationUrl,
                        textureSize: self.textureSize,
                        device: device
                    )
                else {
                    return promise(.failure(TextureDocumentsDirectoryRepositoryError.fileNotFound(destinationUrl.path)))
                }

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

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[IdentifiedTexture], Error> {
        Publishers.MergeMany(
            uuids.map { copyTexture(uuid: $0) }
        )
        .collect()
        .eraseToAnyPublisher()
    }

    /// Recreate the directory and removes textures and thumbnails
    func removeAll() {
        do {
            // Create a new folder
            try FileManager.createNewDirectory(workingDirectoryURL)

            // Removes texture IDs
            textureIds = []
        } catch {
            Logger.standard.error("Failed to reset texture storage: \(error)")
        }
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard let `self` else { return }

            let fileURL = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }

            textureIds.remove(uuid)

            promise(.success(uuid))
        }
        .eraseToAnyPublisher()
    }

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let texture,
                let device = MTLCreateSystemDefaultDevice()
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let fileURL = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                promise(.failure(TextureRepositoryError.fileNotFound(fileURL.path)))
                return
            }

            guard let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            ) else {
                promise(.failure(TextureDocumentsDirectoryRepositoryError.failedToCreateNewTexture))
                return
            }

            do {
                try FileOutput.saveTextureAsData(
                    bytes: newTexture.bytes,
                    to: fileURL
                )
                promise(.success(
                    .init(uuid: uuid, texture: newTexture)
                ))

            } catch {
                promise(.failure(TextureDocumentsDirectoryRepositoryError.failedToUpdateTexture(error)))
            }
        }
        .eraseToAnyPublisher()
    }
}

enum TextureDocumentsDirectoryRepositoryError: Error {
    case failedToCreateNewTexture
    case failedToUpdateTexture(Error)
    case storageNotSynchronized
    case textureSizeIsZero
    case fileNotFound(String)
}
