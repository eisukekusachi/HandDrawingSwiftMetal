//
//  MockTextureLayersDocumentsRepository.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/19.
//

import Foundation
import TextureLayerView

@preconcurrency import MetalKit

final class MockTextureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol, @unchecked Sendable {
    struct DuplicatedTextureCall: Equatable {
        let id: LayerId
        let textureSize: CGSize
        let device: MTLDevice

        static func == (lhs: DuplicatedTextureCall, rhs: DuplicatedTextureCall) -> Bool {
            lhs.id == rhs.id && lhs.textureSize == rhs.textureSize && lhs.device === rhs.device
        }
    }

    struct DuplicatedTexturesCall: Equatable {
        let ids: [LayerId]
        let textureSize: CGSize
        let device: MTLDevice

        static func == (lhs: DuplicatedTexturesCall, rhs: DuplicatedTexturesCall) -> Bool {
            lhs.ids == rhs.ids && lhs.textureSize == rhs.textureSize && lhs.device === rhs.device
        }
    }

    struct WriteCall: Equatable {
        let id: LayerId
        let data: Data
    }

    let workingDirectoryURL: URL = URL(fileURLWithPath: "/tmp/TextureLayerCanvasViewTests")

    var duplicatedTextureCalls: [DuplicatedTextureCall] = []
    var duplicatedTexturesCalls: [DuplicatedTexturesCall] = []
    var writeCalls: [WriteCall] = []

    var duplicatedTextureResult: MTLTexture?
    var duplicatedTexturesResult: [(LayerId, MTLTexture)] = []

    func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
    }

    func restoreStorageFromWorkingDirectory(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws {
    }

    func restoreStorage(
        url sourceFolderURL: URL,
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws -> Bool {
        return false
    }

    func duplicatedTexture(
        _ id: LayerId,
        textureSize: CGSize,
        device: MTLDevice
    ) async -> MTLTexture? {
        duplicatedTextureCalls.append(.init(id: id, textureSize: textureSize, device: device))
        return duplicatedTextureResult
    }

    func duplicatedTextures(
        _ ids: [LayerId],
        textureSize: CGSize,
        device: MTLDevice
    ) async -> [(LayerId, MTLTexture)] {
        duplicatedTexturesCalls.append(.init(ids: ids, textureSize: textureSize, device: device))
        return duplicatedTexturesResult
    }

    @discardableResult
    func addTextureData(data: Data, id: LayerId) async throws -> Bool {
        return false
    }

    @discardableResult
    func removeTexture(_ id: LayerId) throws -> Bool {
        return false
    }

    func removeAll() {
    }

    @discardableResult
    func copyTexture(id: LayerId, to: URL) async throws -> Bool {
        return false
    }

    func writeDataToDisk(id: LayerId, data: Data) async throws {
        writeCalls.append(.init(id: id, data: data))
    }
}
