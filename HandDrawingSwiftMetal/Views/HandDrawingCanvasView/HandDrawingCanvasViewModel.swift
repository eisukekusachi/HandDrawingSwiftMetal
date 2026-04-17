//
//  HandDrawingCanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/02/04.
//

import CanvasView
import Combine
import Foundation
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class HandDrawingCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    let updateCanvasTextureSubject = PassthroughSubject<MTLTexture?, Never>()

    let updateFullCanvasTextureSubject = PassthroughSubject<Void, Never>()

    let textureLayersState: TextureLayersState

    private let dependencies: HandDrawingCanvasViewDependencies

    private var cancellables = Set<AnyCancellable>()

    private var renderer: MTLRendering

    init(
        textureLayersState: TextureLayersState,
        renderer: MTLRendering,
        dependencies: HandDrawingCanvasViewDependencies? = nil
    ) {
        self.textureLayersState = textureLayersState
        self.dependencies = dependencies ?? .init()
        self.renderer = renderer
    }
}

extension HandDrawingCanvasViewModel {

    func duplicateTextureFromDocumentsDirectory(
        _ id: LayerId
    ) async -> MTLTexture? {
        await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            textureSize: textureSize,
            device: renderer.device
        )
    }

    func duplicateTexturesFromDocumentsDirectory(
        _ ids: [LayerId]
    ) async -> [(LayerId, MTLTexture)] {
        await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            textureSize: textureSize,
            device: renderer.device
        )
    }
}

extension HandDrawingCanvasViewModel {

    func saveTextureToDocumentsDirectory(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await dependencies.textureLayersDocumentsRepository.writeDataToDisk(
            id: layerId,
            data: textureData
        )
    }
}
