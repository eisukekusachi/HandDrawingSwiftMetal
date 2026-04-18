//
//  TextureLayersDocumentsRepositoryProtocol.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/12/29.
//

import UIKit

@preconcurrency import MetalKit

public protocol TextureLayersDocumentsRepositoryProtocol: Sendable, AnyObject {

    var workingDirectoryURL: URL { get }

    func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws

    func restoreStorageFromWorkingDirectory(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws

    func restoreStorage(
        url sourceFolderURL: URL,
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws -> Bool

    func duplicatedTexture(
        _ id: LayerId,
        textureSize: CGSize,
        device: MTLDevice
    ) async -> MTLTexture?

    func duplicatedTextures(
        _ ids: [LayerId],
        textureSize: CGSize,
        device: MTLDevice
    ) async -> [(LayerId, MTLTexture)]

    @discardableResult
    func addTextureData(
        data: Data,
        id: LayerId
    ) async throws -> Bool

    @discardableResult
    func removeTexture(
        _ id: LayerId
    ) throws -> Bool

    func removeAll()

    @discardableResult
    func copyTexture(
        id: LayerId,
        to: URL
    ) async throws -> Bool

    func writeDataToDisk(
        id: LayerId,
        data: Data
    ) async throws
}
