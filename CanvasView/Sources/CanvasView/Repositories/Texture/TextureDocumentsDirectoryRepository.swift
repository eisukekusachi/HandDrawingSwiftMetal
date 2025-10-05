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
        renderer: MTLRendering
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
    func initializeStorage(
        configuration: TextureLayerArrayConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {

        if let textureSize = configuration.textureSize,
           FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(workingDirectoryURL)
        ) {
            // Retain IDs
            textureIds = Set(configuration.layers.map { $0.id })

            // Retain the texture size
            setTextureSize(configuration.textureSize ?? .zero)

            return try await .init(
                configuration: configuration,
                resolvedTextureSize: textureSize
            )
        } else {
            return try await initializeStorageWithNewTexture(
                configuration: configuration,
                textureSize: fallbackTextureSize
            )
        }
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: TextureLayerArrayConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {
        guard FileManager.containsAll(
            fileNames: configuration.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        let textureSize = configuration.textureSize ?? defaultTextureSize

        var tmpTextureIds: Set<UUID> = []

        try configuration.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
            )
            guard
                let hexadecimalData = textureData.encodedHexadecimals,
                let _ = MTLTextureCreator.makeTexture(
                    width: Int(textureSize.width),
                    height: Int(textureSize.height),
                    from: hexadecimalData,
                    with: renderer.device
                )
            else {
                let error = NSError(
                    title: String(localized: "Error", bundle: .module),
                    message: String(localized: "Unable to load required data", bundle: .module)
                )
                Logger.error(error)
                throw error
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

        return try await .init(
            configuration: configuration,
            resolvedTextureSize: defaultTextureSize
        )
    }

    private func initializeStorageWithNewTexture(
        configuration: TextureLayerArrayConfiguration,
        textureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {
        guard
            Int(textureSize.width) > canvasMinimumTextureLength &&
            Int(textureSize.height) > canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Texture size is below the minimum", bundle: .main) + ":\(textureSize.width) \(textureSize.height)"
            )
            Logger.error(error)
            throw error
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
            layer.id,
            textureSize: textureSize
        )

        // Set the texture size after the initialization of this repository is completed
        setTextureSize(textureSize)

        return try await .init(
            configuration: .init(configuration, layers: [layer]),
            resolvedTextureSize: textureSize
        )
    }

    func createTexture(_ id: UUID, textureSize: CGSize) async throws {
        if let texture = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        ) {
            try FileOutput.saveTextureAsData(
                bytes: texture.bytes,
                to: workingDirectoryURL.appendingPathComponent(id.uuidString)
            )
            textureIds.insert(id)
        }
    }
    func setTextureSize(_ size: CGSize) {
        _textureSize = size
    }

    /// Copies a texture for the given UUID
    func duplicatedTexture(_ id: UUID) async throws -> IdentifiedTexture {
        if textureSize == .zero {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Texture size is zero", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        let destinationUrl = self.workingDirectoryURL.appendingPathComponent(id.uuidString)

        guard
            let newTexture: MTLTexture = try MTLTextureCreator.makeTexture(
                url: destinationUrl,
                textureSize: self.textureSize,
                with: renderer.device
            )
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: "\(String(localized: "File not found", bundle: .module)):\(destinationUrl.path)"
            )
            Logger.error(error)
            throw error
        }

        return .init(id: id, texture: newTexture)
    }

    /// Copies multiple textures for the given UUIDs
    func duplicatedTextures(_ ids: [UUID]) async throws -> [IdentifiedTexture] {
        try await withThrowingTaskGroup(of: IdentifiedTexture.self) { group in
            for id in ids {
                group.addTask { try await self.duplicatedTexture(id) }
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
            // Do nothing on error
            Logger.error(error)
        }
    }

    func removeTexture(_ id: UUID) throws -> UUID {
        let fileURL = self.workingDirectoryURL.appendingPathComponent(id.uuidString)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        textureIds.remove(id)
        return id
    }

    func addTexture(_ texture: MTLTexture, id: UUID) async throws -> IdentifiedTexture {
        let fileURL = workingDirectoryURL.appendingPathComponent(id.uuidString)

        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "File already exists", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        try FileOutput.saveTextureAsData(
            bytes: texture.bytes,
            to: fileURL
        )
        return .init(id: id, texture: texture)
    }

    @discardableResult
    func updateTexture(texture: MTLTexture?, for id: UUID) async throws -> IdentifiedTexture {
        guard
            let texture
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        let fileURL = workingDirectoryURL.appendingPathComponent(id.uuidString)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: "\(String(localized: "File not found", bundle: .module)):\(fileURL.path)"
            )
            Logger.error(error)
            throw error
        }

        guard let newTexture = await renderer.duplicateTexture(
            texture: texture
        ) else {
            let error = NSError(
                title: String(localized :"Error", bundle: .module),
                message: String(localized :"Failed to create new texture", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        do {
            try FileOutput.saveTextureAsData(bytes: newTexture.bytes, to: fileURL)
            return .init(id: id, texture: newTexture)
        } catch {
            let error = NSError(
                title: String(localized :"Error", bundle: .module),
                message: String(localized :"Failed to update texture", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
    }
}
