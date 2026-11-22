//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

/// Saves the in-progress drawing texture to Storage.
@MainActor
final class TextureLayerCanvasDrawingPersistence {

    /// Active layer id.
    private(set) var activeLayerId: LayerId?

    /// Texture saves are expensive; with rapid strokes, only the latest line is saved after a short delay.
    private let debouncer = Debouncer(delay: 0.25)

    private let saveLayerData: (LayerId, Data, UIImage?) async throws -> Void

    init(
        saveLayerData: @escaping (LayerId, Data, UIImage?) async throws -> Void
    ) {
        self.saveLayerData = saveLayerData
    }

    func throwIfUnsavedDrawing() throws {
        guard activeLayerId == nil else {
            throw Self.saveInProgressError
        }
    }

    /// Debounced save to Storage.
    ///
    /// On failure the screen and Storage images can differ, but it is a rare case, so we only log and prioritize the common case.
    func saveToStorageWithDebouncing(
        layerId: LayerId,
        texture: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) {
        activeLayerId = layerId

        debouncer.perform { [self] in
            Task { @MainActor in
                do {
                    guard let layerId = activeLayerId else { return }

                    let textureData = try await texture.data(
                        device: device,
                        commandQueue: commandQueue
                    )
                    try await saveLayerData(layerId, textureData, texture.makeThumbnail())
                    activeLayerId = nil
                } catch {
                    Logger.error(error)
                    activeLayerId = nil
                }
            }
        }
    }
}

extension TextureLayerCanvasDrawingPersistence {

    static var saveInProgressError: NSError {
        HandDrawingNSError.Code.textureLayerCanvasDrawingSaveInProgress.nsError
    }

    static func isSaveInProgressError(_ error: Error) -> Bool {
        NSError.matches(
            error,
            domain: HandDrawingNSError.domain,
            code: HandDrawingNSError.Code.textureLayerCanvasDrawingSaveInProgress.rawValue
        )
    }
}
