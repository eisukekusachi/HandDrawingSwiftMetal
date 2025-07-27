//
//  TextureLayerDocumentsDirectoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import MetalKit
import SwiftUI
@preconcurrency import Combine

/// A repository that manages on-disk textures and in-memory thumbnails
final class TextureLayerDocumentsDirectoryRepository: TextureDocumentsDirectoryRepository, TextureLayerRepository, @unchecked Sendable {

    let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    private(set) var thumbnails: [UUID: UIImage?] = [:]

    private var cancellables = Set<AnyCancellable>()

    override init(
        storageDirectoryURL: URL,
        directoryName: String,
        textures: Set<UUID> = [],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        super.init(
            storageDirectoryURL: storageDirectoryURL,
            directoryName: directoryName,
            textures: textures,
            renderer: renderer
        )
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    /// Attempts to restore the repository from a given `CanvasConfiguration`
    /// If that is invalid, creates a new texture and initializes the repository with it
    override func initializeStorage(configuration: CanvasConfiguration) async throws -> CanvasConfiguration {
        if FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(workingDirectoryURL)
        ) {
            let textureSize = configuration.textureSize ?? .zero

            // Retain IDs
            textureIds = Set(configuration.layers.map { $0.id })

            // Retain the texture size
            setTextureSize(textureSize)

            try await updateAllThumbnailsAsync(textureSize: textureSize)

            return configuration

        } else {
            let configuration = try await initializeStorageWithNewTexture(configuration.textureSize ?? .zero)
            return configuration
        }
    }

    override func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) async throws {
        guard FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            throw TextureRepositoryError.invalidValue("restoreStorage(from:, with:)")
        }

        guard
            let device = MTLCreateSystemDefaultDevice()
        else { throw TextureRepositoryError.failedToUnwrap }

        var tmpTextureIds: Set<UUID> = []
        var tmpThumbnails: [UUID: UIImage?] = [:]

        try configuration.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
            )
            guard
                let textureSize = configuration.textureSize,
                let hexadecimalData = textureData.encodedHexadecimals,
                let newTexture = MTLTextureCreator.makeTexture(
                    size: textureSize,
                    colorArray: hexadecimalData,
                    with: device
                )
            else {
                throw TextureRepositoryError.failedToUnwrap
            }

            tmpTextureIds.insert(layer.id)
            tmpThumbnails[layer.id] = newTexture.makeThumbnail()
        }

        removeAll()

        // Move all files
        try configuration.layers.forEach { layer in
            try FileManager.default.moveItem(
                at: sourceFolderURL.appendingPathComponent(layer.id.uuidString),
                to: self.workingDirectoryURL.appendingPathComponent(layer.id.uuidString)
            )
        }

        textureIds = tmpTextureIds
        thumbnails = tmpThumbnails

        // Set the texture size after the initialization of this repository is completed
        setTextureSize(textureSize)
    }

    override func createTexture(uuid: UUID, textureSize: CGSize) async throws {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else { return }

        if let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device) {
            try FileOutput.saveTextureAsData(
                bytes: texture.bytes,
                to: workingDirectoryURL.appendingPathComponent(uuid.uuidString)
            )

            textureIds.insert(uuid)
            setThumbnail(texture: texture, for: uuid)
        }
    }

    /// Recreate the directory and removes textures and thumbnails
    override func removeAll() {
        do {
            // Create a new folder
            try FileManager.createNewDirectory(workingDirectoryURL)

            // Remove textures and thumbnails
            textureIds = []
            thumbnails = [:]

        } catch {
            Logger.standard.error("Failed to reset texture storage: \(error)")
        }
    }

    override func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        guard let texture else {
            throw TextureRepositoryError.failedToUnwrap
        }

        let fileURL = workingDirectoryURL.appendingPathComponent(uuid.uuidString)

        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TextureRepositoryError.fileAlreadyExists
        }

        try FileOutput.saveTextureAsData(
            bytes: texture.bytes,
            to: fileURL
        )
        setThumbnail(texture: texture, for: uuid)

        return .init(uuid: uuid, texture: texture)
    }

    override func removeTexture(_ uuid: UUID) throws -> UUID {
        let fileURL = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        textureIds.remove(uuid)
        thumbnails.removeValue(forKey: uuid)
        return uuid
    }

    /// Updates an existing texture for UUID
    override func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let texture,
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

        let fileURL = workingDirectoryURL.appendingPathComponent(uuid.uuidString)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TextureRepositoryError.fileNotFound(fileURL.path)
        }

        guard let newTexture = MTLTextureCreator.duplicateTexture(
            texture: texture,
            with: device
        ) else {
            throw TextureDocumentsDirectoryRepositoryError.failedToCreateNewTexture
        }

        try FileOutput.saveTextureAsData(
            bytes: newTexture.bytes,
            to: fileURL
        )
        setThumbnail(texture: texture, for: uuid)

        return .init(uuid: uuid, texture: newTexture)
    }
}

extension TextureLayerDocumentsDirectoryRepository {

    private func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        guard let texture else {
            Logger.standard.warning("Failed to unwrap texture for \(uuid)")
            return
        }
        thumbnails[uuid] = texture.makeThumbnail()
        objectWillChangeSubject.send(())
    }

    private func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
                for textureId in self.textureIds {
                    let url = self.workingDirectoryURL.appendingPathComponent(textureId.uuidString)
                    if FileManager.default.fileExists(atPath: url.path) {
                        let texture: MTLTexture? = try FileInput.loadTexture(
                            url: url,
                            textureSize: textureSize,
                            device: device
                        )
                        self.setThumbnail(texture: texture, for: textureId)
                    } else {
                        Logger.standard.error("Failed to load texture for \(textureId.uuidString): file not found")
                    }
                }
                promise(.success(()))

            } catch {
                promise(.failure(TextureLayerDocumentsDirectoryRepositoryError.failedToUpdateTexture(error)))
            }
        }
        .eraseToAnyPublisher()
    }

    private func updateAllThumbnailsAsync(textureSize: CGSize) async throws {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else { return }

        for textureId in self.textureIds {
            let url = self.workingDirectoryURL.appendingPathComponent(textureId.uuidString)
            if FileManager.default.fileExists(atPath: url.path) {
                let texture: MTLTexture? = try FileInput.loadTexture(
                    url: url,
                    textureSize: textureSize,
                    device: device
                )
                setThumbnail(texture: texture, for: textureId)
            } else {
                Logger.standard.error("Failed to load texture for \(textureId.uuidString): file not found")
            }
        }
    }
}

enum TextureLayerDocumentsDirectoryRepositoryError: Error {
    case failedToUpdateTexture(Error)
}
