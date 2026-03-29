//
//  TextureLayersDocumentsRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import UIKit

@preconcurrency import MetalKit

private struct TextureSource: Sendable {
    let id: LayerId
    let url: URL
    let width: Int
    let height: Int
    let hexadecimalData: [UInt8]
}

/// Manages and persists `TextureLayers` textures on disk
@MainActor
public final class TextureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol {

    public static let shared: TextureLayersDocumentsRepository = {
        do {
            return try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage"
            )
        } catch {
            fatalError("Failed to initialize TextureLayersDocumentsRepository: \(error)")
        }
    }()

    /// URL of the texture storage
    public let workingDirectoryURL: URL

    private var textureSize: CGSize = .zero

    private init(
        storageDirectoryURL: URL,
        directoryName: String
    ) throws {
        self.workingDirectoryURL = storageDirectoryURL.appendingPathComponent(directoryName)

        try FileManager.createDirectory(workingDirectoryURL)

        // Do not back up because this is an intermediate directory
        var url = workingDirectoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
    }

    public func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> Bool {
        let textureSize = textureLayers.textureSize

        guard
            let layerId: LayerId = textureLayers.layers.first?.id
        else {
            Logger.info("Unable to find layer ID")
            return false
        }

        guard
            Int(textureSize.width) >= textureMinimumLength && Int(textureSize.height) >= textureMinimumLength,
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else {
            Logger.error("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return false
        }

        // Delete all textures in the repository
        removeAll()

        let textureData = try await newTexture.data(
            device: device,
            commandQueue: commandQueue
        )
        try await addTextureData(
            textureData: textureData,
            id: layerId
        )

        // Set the texture size after the initialization of this repository is completed
        self.textureSize = textureSize

        return true
    }

    /// Restore the storage
    /// Verify that the textures already present in `workingDirectory` match the data in `TextureLayersModel`
    public func restoreStorageFromWorkingDirectory(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws {
        let textureSize = try validateStorage(
            in: workingDirectoryURL,
            textureLayers: textureLayers,
            device: device
        )

        self.textureSize = textureSize
    }

    /// Restore the storage
    /// Verify that the textures in `sourceFolderURL` match `TextureLayersModel`,
    /// and if they do, move them to `workingDirectory`
    public func restoreStorage(
        url sourceFolderURL: URL,
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws -> Bool {
        let textureSize = try validateStorage(
            in: sourceFolderURL,
            textureLayers: textureLayers,
            device: device
        )

        self.removeAll()

        try textureLayers.layers.forEach { layer in
            try FileManager.default.moveItem(
                at: sourceFolderURL.appendingPathComponent(layer.id.uuidString),
                to: self.workingDirectoryURL.appendingPathComponent(layer.id.uuidString)
            )
        }

        self.textureSize = textureSize

        return true
    }
}

public extension TextureLayersDocumentsRepository {

    /// Adds texture data
    @discardableResult
    func addTextureData(
        textureData: Data,
        id: LayerId
    ) async throws -> Bool {
        // If it doesn’t exist, add it
        guard
            !FileManager.default.fileExists(atPath: workingDirectoryURL.appendingPathComponent(id.uuidString).path)
        else {
            Logger.info("File already exists")
            return false
        }

        try await writeDataToDisk(
            id: id,
            data: textureData
        )

        return true
    }

    /// Copies a texture for the given `LayerId`
    func duplicatedTexture(
        _ id: LayerId,
        device: MTLDevice
    ) async -> MTLTexture? {
        guard
            Int(textureSize.width) >= textureMinimumLength &&
            Int(textureSize.height) >= textureMinimumLength
        else {
            Logger.info("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return nil
        }

        let destinationUrl = self.workingDirectoryURL.appendingPathComponent(id.uuidString)

        guard
            let newTexture: MTLTexture = try? MTLTextureCreator.makeTexture(
                url: destinationUrl,
                size: textureSize,
                with: device
            )
        else {
            Logger.info("File not found: \(destinationUrl.path)")
            return nil
        }

        return newTexture
    }

    /// Copies multiple textures for the given `LayerId`s
    func duplicatedTextures(
        _ ids: [LayerId],
        device: MTLDevice
    ) async -> [(LayerId, MTLTexture)] {
        guard
            Int(textureSize.width) >= textureMinimumLength,
            Int(textureSize.height) >= textureMinimumLength
        else {
            Logger.info("Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return []
        }

        let width = Int(textureSize.width)
        let height = Int(textureSize.height)

        let sources: [TextureSource] = await withTaskGroup(of: TextureSource?.self) { group in
            for id in ids {
                let url = workingDirectoryURL.appendingPathComponent(id.uuidString)

                group.addTask {
                    do {
                        guard let hexadecimalData = try MTLTextureCreator.loadHexadecimalData(from: url) else {
                            Logger.info("File not found: \(url.path)")
                            return nil
                        }
                        return TextureSource(
                            id: id,
                            url: url,
                            width: width,
                            height: height,
                            hexadecimalData: hexadecimalData
                        )
                    } catch {
                        Logger.info("Failed to load texture source: \(url.path), error: \(error)")
                        return nil
                    }
                }
            }

            var results: [TextureSource] = []
            results.reserveCapacity(ids.count)

            for await result in group {
                if let result {
                    results.append(result)
                }
            }

            return results
        }

        var textures: [(LayerId, MTLTexture)] = []
        textures.reserveCapacity(sources.count)

        for source in sources {
            do {
                if let texture = try MTLTextureCreator.makeTexture(
                    width: source.width,
                    height: source.height,
                    from: source.hexadecimalData,
                    with: device
                ) {
                    textures.append((source.id, texture))
                }
            } catch {
                Logger.info("Failed to create texture: \(source.url.path), error: \(error)")
            }
        }

        return textures
    }

    /// Recreate the directory
    func removeAll() {
        do {
            // Create a new folder
            try FileManager.createNewDirectory(workingDirectoryURL)
        } catch {
            // Do nothing on error
            Logger.error(error)
        }
    }

    /// Removes the texture for the specified `LayerId` from the Documents directory
    @discardableResult
    func removeTexture(_ id: LayerId) throws -> Bool {
        let fileURL = workingDirectoryURL.appendingPathComponent(id.uuidString)

        // If the file exists, delete it
        guard
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            // Log the error only, as nothing can be done
            Logger.info("Unable to find \(id.uuidString)")
            return false
        }
        try FileManager.default.removeItem(at: fileURL)

        return true
    }

    @discardableResult
    func copyTexture(
        id: LayerId,
        to destinationURL: URL
    ) async throws -> Bool {
        let sourceURL = workingDirectoryURL.appendingPathComponent(id.uuidString)
        let destinationURL = destinationURL.appendingPathComponent(id.uuidString)

        // If the file exists, copy it
        guard
            FileManager.default.fileExists(atPath: sourceURL.path)
        else {
            Logger.info("Unable to find \(id.uuidString)")
            return false
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return true
    }

    func writeDataToDisk(
        id: LayerId,
        data: Data
    ) async throws {
        try data.write(
            to: workingDirectoryURL.appendingPathComponent(id.uuidString),
            options: .atomic
        )
    }
}

private extension TextureLayersDocumentsRepository {
    func validateStorage(
        in directoryURL: URL,
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws -> CGSize {
        guard FileManager.containsAllFileNames(
            fileNames: textureLayers.layers.map { $0.fileName },
            in: FileManager.contentsOfDirectory(directoryURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to find texture layer files")
            )
            Logger.error(error)
            throw error
        }

        let textureSize = textureLayers.textureSize

        try textureLayers.layers.forEach { layer in
            let textureData = try Data(
                contentsOf: directoryURL.appendingPathComponent(layer.id.uuidString)
            )

            guard
                let hexadecimalData = textureData.encodedHexadecimals,
                let _ = try MTLTextureCreator.makeTexture(
                    width: Int(textureSize.width),
                    height: Int(textureSize.height),
                    from: hexadecimalData,
                    with: device
                )
            else {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Unable to load required data")
                )
                Logger.error(error)
                throw error
            }
        }

        return textureSize
    }
}
