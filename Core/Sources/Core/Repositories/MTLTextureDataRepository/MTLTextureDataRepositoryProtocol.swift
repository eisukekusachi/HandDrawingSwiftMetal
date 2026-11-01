//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation

@preconcurrency import MetalKit

/// Repository abstraction that stores `MTLTexture` data keyed by id.
public protocol MTLTextureDataRepositoryProtocol: Sendable, AnyObject {

    func initializeTexture(
        id: UUID,
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws

    func restoreTextures(
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws

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

    func removeAll() throws

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
