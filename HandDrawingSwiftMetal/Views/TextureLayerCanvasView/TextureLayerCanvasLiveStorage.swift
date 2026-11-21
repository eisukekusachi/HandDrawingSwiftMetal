//
//  Created by Eisuke Kusachi
//

import CanvasView
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

/// Persists the in-GPU active layer and debounced stroke-to-disk writes.
@MainActor
final class TextureLayerCanvasLiveStorage {

    /// Layer whose pixels are held in the canvas `currentTexture`.
    private(set) var currentTextureLayerId: LayerId?

    private let strokeSaveDebouncer = DrawingDebouncer(delay: 0.25)

    private let writeDataToDisk: (LayerId, Data) async throws -> Void
    private let updateThumbnail: (LayerId, UIImage?) -> Void

    init(
        writeDataToDisk: @escaping (LayerId, Data) async throws -> Void,
        updateThumbnail: @escaping (LayerId, UIImage?) -> Void
    ) {
        self.writeDataToDisk = writeDataToDisk
        self.updateThumbnail = updateThumbnail
    }

    func resetActiveLayer() {
        currentTextureLayerId = nil
    }

    func setActiveLayer(_ layerId: LayerId) {
        currentTextureLayerId = layerId
    }

    /// Saves the active layer texture to Storage after drawing quiets down (debounced).
    func scheduleSaveAfterStroke(
        texture: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) {
        guard let layerId = currentTextureLayerId else { return }

        strokeSaveDebouncer.perform { [writeDataToDisk, updateThumbnail] in
            let textureData = try await texture.data(
                device: device,
                commandQueue: commandQueue
            )
            try await writeDataToDisk(layerId, textureData)
            await MainActor.run {
                updateThumbnail(layerId, texture.makeThumbnail())
            }
        }
    }

    /// Immediate write of `texture` for `currentTextureLayerId` (layer switch / zip save).
    func flushToStorage(
        texture: MTLTexture?,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        guard let texture, let layerId = currentTextureLayerId else { return }

        let textureData = try await texture.data(
            device: device,
            commandQueue: commandQueue
        )
        try await writeDataToDisk(layerId, textureData)
        updateThumbnail(layerId, texture.makeThumbnail())
    }
}