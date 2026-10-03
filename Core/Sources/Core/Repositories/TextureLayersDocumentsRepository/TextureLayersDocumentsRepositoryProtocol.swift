//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation

@preconcurrency import MetalKit

/// Stores texture bytes in a directory, keyed by id.
/// Layer titles, order, and visibility stay with the caller.
public protocol TextureLayersDocumentsRepositoryProtocol: Sendable, AnyObject {

    var workingDirectoryURL: URL { get }

    func initializeStorage(
        id: UUID,
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws

    func restoreStorageFromWorkingDirectory(
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws

    func restoreStorage(
        from sourceFolderURL: URL,
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> Bool

    func duplicatedTexture(
        _ id: UUID,
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> MTLTexture

    func duplicatedTextures(
        _ ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> [(UUID, MTLTexture)]

    @discardableResult
    func addTextureData(
        data: Data,
        id: UUID
    ) async throws -> Bool

    @discardableResult
    func removeTexture(
        _ id: UUID
    ) throws -> Bool

    func removeAll()

    @discardableResult
    func copyTexture(
        id: UUID,
        to: URL
    ) async throws -> Bool

    func writeDataToDisk(
        id: UUID,
        data: Data
    ) async throws
}
