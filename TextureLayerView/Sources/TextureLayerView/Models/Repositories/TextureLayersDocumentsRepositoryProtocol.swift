//
//  TextureLayersDocumentsRepositoryProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/29.
//

import CanvasView
import Foundation
@preconcurrency import MetalKit

@MainActor
public protocol TextureLayersDocumentsRepositoryProtocol: AnyObject {

    var workingDirectoryURL: URL { get }

    func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws

    func restoreStorageFromCoreData(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws

    func restoreStorageFromSavedData(
        url sourceFolderURL: URL,
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws

    func duplicatedTexture(_ id: LayerId, device: MTLDevice) async throws -> IdentifiedTexture
    func duplicatedTextures(_ ids: [LayerId], device: MTLDevice) async throws -> [IdentifiedTexture]

    func removeAll()
    func removeTexture(_ id: LayerId) throws

    func addTexture(texture: MTLTexture, id: LayerId, device: MTLDevice) async throws
    func writeTextureToDisk(texture: MTLTexture, for id: LayerId, device: MTLDevice) async throws
}
