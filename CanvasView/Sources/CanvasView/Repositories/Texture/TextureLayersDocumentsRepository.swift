//
//  TextureLayersDocumentsRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Foundation
@preconcurrency import MetalKit

/// Manages and persists `TextureLayers` textures on disk
@MainActor public final class TextureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol {

    /// URL of the texture storage
    public let workingDirectoryURL: URL

    private let renderer: MTLRendering

    private var textureSize: CGSize = .zero

    public init(
        storageDirectoryURL: URL,
        directoryName: String,
        renderer: MTLRendering
    ) {
        self.renderer = renderer

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

    public func initializeStorage(
        newTextureLayersState: TextureLayersState
    ) async throws {
        let textureSize = newTextureLayersState.textureSize
        guard
            let layerId: LayerId = newTextureLayersState.layers.first?.id,
            Int(textureSize.width) >= canvasMinimumTextureLength && Int(textureSize.height) >= canvasMinimumTextureLength,
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: renderer.device
            )
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

        try await addTexture(texture: newTexture, id: layerId)

        // Set the texture size after the initialization of this repository is completed
        self.textureSize = textureSize
    }

    /// Restore the storage from Core Data.
    /// Verify that the textures already present in `workingDirectory` match the data in `TextureLayersState`
    public func restoreStorageFromCoreData(
        textureLayersState: TextureLayersState
    ) throws {
        guard FileManager.containsAllFileNames(
            fileNames: textureLayersState.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(workingDirectoryURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Unable to find texture layer files", bundle: .main)
            )
            Logger.error(error)
            throw error
        }

        let textureSize = textureLayersState.textureSize

        try textureLayersState.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: workingDirectoryURL.appendingPathComponent(layer.id.uuidString)
            )
            // Check if the data can be converted into a texture
            guard
                let hexadecimalData = textureData.encodedHexadecimals,
                let _ = try MTLTextureCreator.makeTexture(
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
        }

        // Do nothing since the textures already exist in workingDirectory

        // Retain the texture size
        self.textureSize = textureLayersState.textureSize
    }

    /// Restore the storage from the saved data.
    /// Verify that the textures in `sourceFolderURL` match `TextureLayersState`,
    /// and if they do, move them to `workingDirectory`
    public func restoreStorageFromSavedData(
        url sourceFolderURL: URL,
        textureLayersState: TextureLayersState
    ) async throws {
        guard FileManager.containsAllFileNames(
            fileNames: textureLayersState.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(sourceFolderURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Unable to find texture layer files", bundle: .main)
            )
            Logger.error(error)
            throw error
        }

        let textureSize = textureLayersState.textureSize

        try textureLayersState.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
            )
            // Check if the data can be converted into a texture
            guard
                let hexadecimalData = textureData.encodedHexadecimals,
                let _ = try MTLTextureCreator.makeTexture(
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
        }

        // Delete all textures in the repository
        self.removeAll()

        // Move all files
        try textureLayersState.layers.forEach { layer in
            try FileManager.default.moveItem(
                at: sourceFolderURL.appendingPathComponent(layer.id.uuidString),
                to: self.workingDirectoryURL.appendingPathComponent(layer.id.uuidString)
            )
        }

        // Set the texture size after the initialization of this repository is completed
        self.textureSize = textureSize
    }
}

extension TextureLayersDocumentsRepository {
    /// Copies a texture for the given `LayerId`
    public func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture {
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
                size: textureSize,
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

    /// Copies multiple textures for the given `LayerId`s
    public func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture] {
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

    /// Recreate the directory
    public func removeAll() {
        do {
            // Create a new folder
            try FileManager.createNewDirectory(workingDirectoryURL)
        } catch {
            // Do nothing on error
            Logger.error(error)
        }
    }

    /// Removes the texture for the specified `LayerId` from the Documents directory
    public func removeTexture(_ id: LayerId) throws {
        let fileURL = workingDirectoryURL.appendingPathComponent(id.uuidString)

        // If the file exists, delete it
        guard
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            // Log the error only, as nothing can be done
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to find \(id.uuidString)", bundle: .module)
            )
            throw error
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Adds a texture. Although `MTLTexture` is a class type, the texture is duplicated into the Documents directory,
    /// so the instance passed as an argument does not need to be a new one
    public func addTexture(texture: MTLTexture, id: LayerId) async throws {
        // If it doesn’t exist, add it
        guard
            !FileManager.default.fileExists(atPath: workingDirectoryURL.appendingPathComponent(id.uuidString).path)
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "File already exists", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        try await IdentifiedTexture(
            id: id,
            texture: texture
        ).write(
            in: workingDirectoryURL,
            device: renderer.device
        )
    }

    /// Writes the texture to disk by duplicating it into the Documents directory.
    /// Since `MTLTexture` is a reference type, the passed instance does not need to be newly created.
    public func writeTextureToDisk(texture: MTLTexture, for id: LayerId) async throws {
        // If the file exists, update it
        guard
            FileManager.default.fileExists(atPath: workingDirectoryURL.appendingPathComponent(id.uuidString).path)
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: "\(String(localized: "File not found", bundle: .module))"
            )
            Logger.error(error)
            throw error
        }

        do {
            try await IdentifiedTexture(
                id: id,
                texture: texture
            ).write(
                in: workingDirectoryURL,
                device: renderer.device
            )
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
