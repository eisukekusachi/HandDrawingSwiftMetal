//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation

@preconcurrency import MetalKit

/// Stores layer texture data as files on local disk, keyed by id.
public final class LocalTextureFileRepository: MTLTextureDataRepositoryProtocol {

    private let fileManager: FileManaging
    /// Live on-disk directory for the current layer textures, one file per id.
    private let localTextureDirectoryURL: URL

    public init(
        storageDirectoryURL: URL,
        directoryName: String,
        fileManager: FileManaging = FileManagerWrapper()
    ) throws {
        self.fileManager = fileManager
        self.localTextureDirectoryURL = storageDirectoryURL.appendingPathComponent(directoryName)

        try fileManager.createDirectory(at: localTextureDirectoryURL, withIntermediateDirectories: true)
        // Do not back up because this is an intermediate directory
        try excludeFromBackup(localTextureDirectoryURL)
    }

    public func initializeTexture(
        id: UUID,
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        guard
            Int(textureSize.width) >= textureMinimumLength && Int(textureSize.height) >= textureMinimumLength,
            let newTexture = TextureBytes.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        try removeAll()

        let textureData = try await newTexture.data(
            device: device,
            commandQueue: commandQueue
        )
        try await addTextureData(
            data: textureData,
            id: id
        )
    }

    public func validateTextureFilesInLocalDirectory(
        ids: [UUID],
        textureSize: CGSize
    ) throws {
        try validateTextureFiles(
            from: localTextureDirectoryURL,
            ids: ids,
            textureSize: textureSize
        )
    }

    public func restoreStorage(
        from sourceFolderURL: URL,
        ids: [UUID],
        textureSize: CGSize
    ) async throws {
        try validateTextureFiles(
            from: sourceFolderURL,
            ids: ids,
            textureSize: textureSize
        )

        try replaceLocalTextureDirectoryAfterStaging { stagingURL in
            try copyLayerTextures(
                ids: ids,
                from: sourceFolderURL,
                to: stagingURL
            )
        }
    }
}

public extension LocalTextureFileRepository {

    @discardableResult
    func addTextureData(
        data: Data,
        id: UUID
    ) async throws -> Bool {
        guard
            !fileManager.fileExists(atPath: localTextureDirectoryURL.appendingPathComponent(id.uuidString).path)
        else {
            Logger.info("File already exists")
            return false
        }

        try await writeDataToDisk(
            id: id,
            data: data
        )

        return true
    }

    func duplicatedTexture(
        _ id: UUID,
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> MTLTexture {
        guard
            Int(textureSize.width) >= textureMinimumLength &&
            Int(textureSize.height) >= textureMinimumLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        let destinationUrl = localTextureDirectoryURL.appendingPathComponent(id.uuidString)

        guard
            let newTexture: MTLTexture = try TextureBytes.makeTexture(
                url: destinationUrl,
                size: textureSize,
                fileManager: fileManager,
                with: device
            )
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "File not found: \(destinationUrl.path)"
                )
            )
            Logger.error(error)
            throw error
        }

        return newTexture
    }

    func duplicatedTextures(
        _ ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> [(UUID, MTLTexture)] {
        guard
            Int(textureSize.width) >= textureMinimumLength,
            Int(textureSize.height) >= textureMinimumLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        let width = Int(textureSize.width)
        let height = Int(textureSize.height)
        let fileManager = fileManager
        let sources: [TextureSource] = try await withThrowingTaskGroup(of: TextureSource.self) { group in
            for id in ids {
                let url = localTextureDirectoryURL.appendingPathComponent(id.uuidString)

                group.addTask {
                    guard
                        let hexadecimalData = try TextureBytes.loadHexadecimalData(
                            from: url,
                            fileManager: fileManager
                        )
                    else {
                        let error = NSError(
                            title: String(localized: "Error"),
                            message: String(localized: "File not found: \(url.path)")
                        )
                        Logger.error(error)
                        throw error
                    }
                    return TextureSource(
                        id: id,
                        width: width,
                        height: height,
                        hexadecimalData: hexadecimalData
                    )
                }
            }

            var results: [TextureSource] = []
            results.reserveCapacity(ids.count)

            for try await result in group {
                results.append(result)
            }

            return results
        }

        var textures: [(UUID, MTLTexture)] = []
        textures.reserveCapacity(sources.count)

        for source in sources {
            let texture = try TextureBytes.makeTexture(
                width: source.width,
                height: source.height,
                from: source.hexadecimalData,
                with: device
            )
            textures.append((source.id, texture))
        }

        return textures
    }

    func removeAll() throws {
        if fileManager.fileExists(atPath: localTextureDirectoryURL.path) {
            try fileManager.removeItem(at: localTextureDirectoryURL)
        }
        try fileManager.createDirectory(at: localTextureDirectoryURL, withIntermediateDirectories: true)
    }

    @discardableResult
    func removeTexture(_ id: UUID) throws -> Bool {
        let fileURL = localTextureDirectoryURL.appendingPathComponent(id.uuidString)

        guard
            fileManager.fileExists(atPath: fileURL.path)
        else {
            Logger.info("Unable to find \(id.uuidString)")
            return false
        }
        try fileManager.removeItem(at: fileURL)

        return true
    }

    @discardableResult
    func copyTexture(
        id: UUID,
        to destinationURL: URL
    ) async throws -> Bool {
        let sourceURL = localTextureDirectoryURL.appendingPathComponent(id.uuidString)
        let destinationFileURL = destinationURL.appendingPathComponent(id.uuidString)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "File not found: \(sourceURL.path)")
            )
            Logger.error(error)
            throw error
        }

        try fileManager.copyItem(at: sourceURL, to: destinationFileURL)

        return true
    }

    func writeDataToDisk(
        id: UUID,
        data: Data
    ) async throws {
        let url = localTextureDirectoryURL.appendingPathComponent(id.uuidString)

        let fileManager = fileManager
        try await Task.detached(priority: .utility) { [data, url, fileManager] in
            try writeDataAtomically(data: data, to: url, fileManager: fileManager)
        }.value
    }
}

private extension LocalTextureFileRepository {

    func excludeFromBackup(_ directoryURL: URL) throws {
        var url = directoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
    }

    func replaceLocalTextureDirectoryAfterStaging(
        prepareStaging: (URL) throws -> Void
    ) throws {
        let stagingURL = localTextureDirectoryURL.temporaryUniqueURL()
        let backupURL = localTextureDirectoryURL.temporaryUniqueURL()

        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: stagingURL)
            try? fileManager.removeItem(at: backupURL)
        }

        // Prepare staging via the caller.
        try prepareStaging(stagingURL)

        // Move the local texture directory to the backup directory.
        try fileManager.moveItem(at: localTextureDirectoryURL, to: backupURL)

        do {
            // Move the staging directory to the local texture directory path.
            try fileManager.moveItem(at: stagingURL, to: localTextureDirectoryURL)
        } catch {
            // Move the backup directory back to the local texture directory path.
            if fileManager.fileExists(atPath: backupURL.path),
               !fileManager.fileExists(atPath: localTextureDirectoryURL.path) {
                try? fileManager.moveItem(at: backupURL, to: localTextureDirectoryURL)
            }
            throw error
        }

        // The swapped-in directory is a new folder, so the backup exclusion has to be set again.
        // Failure here must not undo a completed swap.
        try? excludeFromBackup(localTextureDirectoryURL)
    }

    func copyLayerTextures(
        ids: [UUID],
        from sourceDirectoryURL: URL,
        to destinationDirectoryURL: URL
    ) throws {
        try ids.forEach { id in
            try fileManager.copyItem(
                at: sourceDirectoryURL.appendingPathComponent(id.uuidString),
                to: destinationDirectoryURL.appendingPathComponent(id.uuidString)
            )
        }
    }

    /// Confirms each id has a pixel file matching `textureSize`. Does not create GPU textures.
    func validateTextureFiles(
        from directoryURL: URL,
        ids: [UUID],
        textureSize: CGSize
    ) throws {
        let width = Int(textureSize.width)
        let height = Int(textureSize.height)
        // Texture size must be at least the minimum drawable length.
        guard width >= textureMinimumLength, height >= textureMinimumLength else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        // Each id must have a pixel file in the directory.
        guard containsAllFileNames(
            fileNames: ids.map(\.uuidString),
            in: fileURLs
        ) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to find texture layer files")
            )
            Logger.error(error)
            throw error
        }

        let expectedByteCount = width * height * TextureBytes.bytesPerPixel

        try ids.forEach { id in
            let filePath = directoryURL.appendingPathComponent(id.uuidString).path
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            // File size must be readable without loading pixel bytes.
            guard let fileSize = attributes[.size] as? NSNumber else {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Unable to load required data")
                )
                Logger.error(error)
                throw error
            }

            // File size must match width * height * bytes per pixel.
            guard fileSize.intValue == expectedByteCount else {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Invalid value")
                )
                Logger.error(error)
                throw error
            }
        }
    }

    func containsAllFileNames(fileNames: [String], in fileURLs: [URL]) -> Bool {
        guard !fileNames.isEmpty else { return false }
        return Set(fileNames).isSubset(of: Set(fileURLs.map(\.lastPathComponent)))
    }
}

private func writeDataAtomically(
    data: Data,
    to url: URL,
    fileManager: FileManaging
) throws {
    let temporaryURL = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
    guard fileManager.createFile(atPath: temporaryURL.path, contents: data, attributes: nil) else {
        throw CocoaError(.fileWriteUnknown)
    }

    do {
        if fileManager.fileExists(atPath: url.path) {
            guard
                try fileManager.replaceItemAt(
                    url,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: []
                ) != nil
            else {
                throw CocoaError(.fileWriteUnknown)
            }
        } else {
            try fileManager.moveItem(at: temporaryURL, to: url)
        }
    } catch {
        try? fileManager.removeItem(at: temporaryURL)
        throw error
    }

    if fileManager.fileExists(atPath: temporaryURL.path) {
        try? fileManager.removeItem(at: temporaryURL)
    }
}

private enum TextureBytes {
    static let bytesPerPixel = 4

    static func loadHexadecimalData(
        from url: URL,
        fileManager: FileManaging
    ) throws -> [UInt8]? {
        guard let data = fileManager.contents(atPath: url.path) else { return nil }
        guard !data.isEmpty else { return nil }
        return [UInt8](data)
    }

    static func makeTexture(
        url: URL,
        size: CGSize,
        fileManager: FileManaging,
        with device: MTLDevice
    ) throws -> MTLTexture? {
        guard
            let hexadecimalData = try loadHexadecimalData(from: url, fileManager: fileManager)
        else { return nil }
        return try makeTexture(
            width: Int(size.width),
            height: Int(size.height),
            from: hexadecimalData,
            with: device
        )
    }

    static func makeTexture(
        width: Int,
        height: Int,
        with device: MTLDevice
    ) -> MTLTexture? {
        guard width >= textureMinimumLength, height >= textureMinimumLength else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Texture size is below the minimum: \(width) \(height)")
            )
            Logger.error(error)
            return nil
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [
            .renderTarget,
            .shaderRead,
            .shaderWrite
        ]
        return device.makeTexture(descriptor: textureDescriptor)
    }

    static func makeTexture(
        width: Int,
        height: Int,
        from colorArray: [UInt8],
        with device: MTLDevice
    ) throws -> MTLTexture {
        guard colorArray.count == width * height * bytesPerPixel else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid value")
            )
            Logger.error(error)
            throw error
        }

        let bytesPerRow = bytesPerPixel * width

        guard let texture = makeTexture(
            width: width,
            height: height,
            with: device
        ) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create texture")
            )
            Logger.error(error)
            throw error
        }

        colorArray.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                slice: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerRow * height
            )
        }

        return texture
    }
}

private struct TextureSource: Sendable {
    let id: UUID
    let width: Int
    let height: Int
    let hexadecimalData: [UInt8]
}
