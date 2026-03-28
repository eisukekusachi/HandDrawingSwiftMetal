//
//  TextureLayersDocumentsRepositoryProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/29.
//

import UIKit

@preconcurrency import MetalKit

@MainActor
public protocol TextureLayersDocumentsRepositoryProtocol: AnyObject {

    var workingDirectoryURL: URL { get }

    @discardableResult
    func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws -> Bool

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
        device: MTLDevice
    ) async throws -> MTLTexture?

    func duplicatedTextures(
        _ ids: [LayerId],
        device: MTLDevice
    ) async throws -> [(LayerId, MTLTexture)]

    @discardableResult
    func addTexture(
        texture: MTLTexture,
        id: LayerId,
        device: MTLDevice
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

    func writeTextureToDisk(
        id: LayerId,
        texture: MTLTexture,
        device: MTLDevice
    ) async throws
}
