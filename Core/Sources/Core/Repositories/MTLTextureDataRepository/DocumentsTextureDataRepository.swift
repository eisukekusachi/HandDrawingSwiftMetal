//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation

@preconcurrency import MetalKit

/// Stores `MTLTexture` data in a `Documents` directory, keyed by id.
public final class DocumentsTextureDataRepository: MTLTextureDataRepositoryProtocol {

    @MainActor
    public static let shared = {
        do {
            return try DocumentsTextureDataRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                fileManager: FileManagerWrapper()
            )
        } catch {
            fatalError("Failed to initialize DocumentsTextureDataRepository: \(error)")
        }
    }()

    private let fileManager: FileManaging
    private let workingDirectoryURL: URL

    init(
        storageDirectoryURL: URL,
        directoryName: String,
        fileManager: FileManaging = FileManagerWrapper()
    ) throws {
        self.fileManager = fileManager
        self.workingDirectoryURL = storageDirectoryURL.appendingPathComponent(directoryName)

        try fileManager.createDirectory(at: workingDirectoryURL, withIntermediateDirectories: true)
        // Do not back up because this is an intermediate directory
        try excludeFromBackup(workingDirectoryURL)
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

    public func restoreTextures(
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws {
        try loadTexturesIfValid(
            from: workingDirectoryURL,
            ids: ids,
            textureSize: textureSize,
            device: device
        )
    }

    public func restoreStorage(
        from sourceFolderURL: URL,
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws {
        try loadTexturesIfValid(
            from: sourceFolderURL,
            ids: ids,
            textureSize: textureSize,
            device: device
        )

        try replaceWorkingStorageAfterStaging { stagingURL in
            try copyLayerTextures(
                ids: ids,
                from: sourceFolderURL,
                to: stagingURL
            )
        }
    }
}

public extension DocumentsTextureDataRepository {

    @discardableResult
    func addTextureData(
        data: Data,
        id: UUID
    ) async throws -> Bool {
        guard
            !fileManager.fileExists(atPath: workingDirectoryURL.appendingPathComponent(id.uuidString).path)
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

        let destinationUrl = workingDirectoryURL.appendingPathComponent(id.uuidString)

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
                let url = workingDirectoryURL.appendingPathComponent(id.uuidString)

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
        if fileManager.fileExists(atPath: workingDirectoryURL.path) {
            try fileManager.removeItem(at: workingDirectoryURL)
        }
        try fileManager.createDirectory(at: workingDirectoryURL, withIntermediateDirectories: true)
    }

    @discardableResult
    func removeTexture(_ id: UUID) throws -> Bool {
        let fileURL = workingDirectoryURL.appendingPathComponent(id.uuidString)

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
        let sourceURL = workingDirectoryURL.appendingPathComponent(id.uuidString)
        let destinationFileURL = destinationURL.appendingPathComponent(id.uuidString)

        guard
            fileManager.fileExists(atPath: sourceURL.path)
        else {
            Logger.info("Unable to find \(id.uuidString)")
            return false
        }

        try fileManager.copyItem(at: sourceURL, to: destinationFileURL)

        return true
    }

    func writeDataToDisk(
        id: UUID,
        data: Data
    ) async throws {
        let url = workingDirectoryURL.appendingPathComponent(id.uuidString)

        let fileManager = fileManager
        try await Task.detached(priority: .utility) { [data, url, fileManager] in
            try writeDataAtomically(data: data, to: url, fileManager: fileManager)
        }.value
    }
}

private extension DocumentsTextureDataRepository {

    func excludeFromBackup(_ directoryURL: URL) throws {
        var url = directoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
    }

    func siblingDirectoryURL(prefix: String) -> URL {
        workingDirectoryURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "\(workingDirectoryURL.lastPathComponent)-\(prefix)-\(UUID().uuidString)"
            )
    }

    func replaceWorkingStorageAfterStaging(
        prepareStaging: (URL) throws -> Void
    ) throws {
        let stagingURL = siblingDirectoryURL(prefix: "staging")
        let backupURL = siblingDirectoryURL(prefix: "backup")

        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: stagingURL)
            try? fileManager.removeItem(at: backupURL)
        }

        // Prepare staging via the caller.
        try prepareStaging(stagingURL)

        // Move the working directory to the backup directory.
        try fileManager.moveItem(at: workingDirectoryURL, to: backupURL)

        do {
            // Move the staging directory to the working directory path.
            try fileManager.moveItem(at: stagingURL, to: workingDirectoryURL)
        } catch {
            // Move the backup directory back to the working directory path.
            if fileManager.fileExists(atPath: backupURL.path),
               !fileManager.fileExists(atPath: workingDirectoryURL.path) {
                try? fileManager.moveItem(at: backupURL, to: workingDirectoryURL)
            }
            throw error
        }

        // The swapped-in directory is a new folder, so the backup exclusion has to be set again.
        // Failure here must not undo a completed swap.
        try? excludeFromBackup(workingDirectoryURL)
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

    func loadTexturesIfValid(
        from directoryURL: URL,
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
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

        try ids.forEach { id in
            let filePath = directoryURL.appendingPathComponent(id.uuidString).path
            guard let textureData = fileManager.contents(atPath: filePath) else {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Unable to load required data")
                )
                Logger.error(error)
                throw error
            }

            guard !textureData.isEmpty else {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Unable to load required data")
                )
                Logger.error(error)
                throw error
            }

            let _ = try TextureBytes.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                from: [UInt8](textureData),
                with: device
            )
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
        let bytesPerPixel = 4

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
