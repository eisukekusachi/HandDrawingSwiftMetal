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
class TextureDocumentsDirectoryRepository: TextureRepository, @unchecked Sendable {
    /// The directory name where texture files are stored
    let directoryName: String

    /// The URL of the texture storage. Define it as `var` to allow modification of its metadata
    let workingDirectoryURL: URL

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

        do {
            try FileManager.createDirectory(workingDirectoryURL)
        } catch {
            Logger.error(error)
        }

        // Do not back up because this is an intermediate directory
        do {
            var url = workingDirectoryURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
        } catch {
            Logger.error(error)
        }
    }

    /// Attempts to restore the repository from a given `CanvasConfiguration`
    /// If that is invalid, creates a new texture and initializes the repository with it
    func initializeStorage(configuration: CanvasConfiguration) async throws -> CanvasConfiguration {
        if FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(workingDirectoryURL)
        ) {
            // Retain IDs
            textureIds = Set(configuration.layers.map { $0.id })

            // Retain the texture size
            setTextureSize(configuration.textureSize ?? .zero)

            return configuration
        } else {
            let configuration = try await initializeStorageWithNewTexture(configuration.textureSize ?? .zero)
            return configuration
        }
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) async throws {
        guard FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            throw TextureRepositoryError.invalidValue("restoreStorage(from:, with:)")
        }

        guard
            let device = MTLCreateSystemDefaultDevice()
        else {
            throw TextureRepositoryError.failedToUnwrap
        }

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

        textureIds = tmpTextureIds

        // Set the texture size after the initialization of this repository is completed
        setTextureSize(textureSize)
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) async throws -> CanvasConfiguration {
        guard
            Int(textureSize.width) > MTLRenderer.threadGroupLength &&
                Int(textureSize.height) > MTLRenderer.threadGroupLength
        else {
            Logger.standard.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            throw TextureRepositoryError.invalidTextureSize
        }

        // Delete all textures in the repository
        removeAll()

        let layer = TextureLayerModel(
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )

        try await createTexture(
            uuid: layer.id,
            textureSize: textureSize
        )

        // Set the texture size after the initialization of this repository is completed
        setTextureSize(textureSize)

        return .init(textureSize: textureSize, layers: [layer])
    }

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {
        guard
            let device = MTLCreateSystemDefaultDevice()
        else { return }

        if let texture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device) {
            try FileOutput.saveTextureAsData(
                bytes: texture.bytes,
                to: workingDirectoryURL.appendingPathComponent(uuid.uuidString)
            )
            textureIds.insert(uuid)
        }
    }
    func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        if textureSize == .zero {
            throw TextureDocumentsDirectoryRepositoryError.textureSizeIsZero
        }

        let destinationUrl = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

        guard
            let device = MTLCreateSystemDefaultDevice(),
            let newTexture: MTLTexture = try FileInput.loadTexture(
                url: destinationUrl,
                textureSize: self.textureSize,
                device: device
            )
        else {
            throw TextureDocumentsDirectoryRepositoryError.fileNotFound(destinationUrl.path)
        }

        return .init(uuid: uuid, texture: newTexture)
    }

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) async throws -> [IdentifiedTexture] {
        try await withThrowingTaskGroup(of: IdentifiedTexture.self) { group in
            for id in uuids {
                group.addTask { try await self.copyTexture(uuid: id) }
            }

            var results: [IdentifiedTexture] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
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

    func removeTexture(_ uuid: UUID) throws -> UUID {
        let fileURL = self.workingDirectoryURL.appendingPathComponent(uuid.uuidString)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        textureIds.remove(uuid)
        return uuid
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
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
        return .init(uuid: uuid, texture: texture)
    }

    @discardableResult
    func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
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

        do {
            try FileOutput.saveTextureAsData(bytes: newTexture.bytes, to: fileURL)
            return .init(uuid: uuid, texture: newTexture)
        } catch {
            throw TextureDocumentsDirectoryRepositoryError.failedToUpdateTexture(error)
        }
    }
}

enum TextureDocumentsDirectoryRepositoryError: Error {
    case failedToCreateNewTexture
    case failedToUpdateTexture(Error)
    case storageNotSynchronized
    case textureSizeIsZero
    case fileNotFound(String)
}
