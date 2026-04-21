//
//  TextureLayerCanvasViewModel.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/18.
//

import CanvasView
import Combine
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class TextureLayerCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    let updateCanvasTextureSubject = PassthroughSubject<MTLTexture?, Never>()

    let updateFullCanvasTextureSubject = PassthroughSubject<Void, Never>()

    let textureLayersState: TextureLayersState

    private let dependencies: TextureLayerCanvasViewDependencies

    private var cancellables = Set<AnyCancellable>()

    private var renderer: MTLRendering

    init(
        textureLayersState: TextureLayersState,
        renderer: MTLRendering,
        dependencies: TextureLayerCanvasViewDependencies? = nil
    ) {
        self.textureLayersState = textureLayersState
        self.dependencies = dependencies ?? .init()
        self.renderer = renderer
    }
}

extension TextureLayerCanvasViewModel {

    func duplicateTextureFromDocumentsDirectory(
        _ id: LayerId
    ) async throws -> MTLTexture? {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            textureSize: textureSize,
            device: renderer.device
        )
    }

    func duplicateTexturesFromDocumentsDirectory(
        _ ids: [LayerId]
    ) async throws -> [(LayerId, MTLTexture)] {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            textureSize: textureSize,
            device: renderer.device
        )
    }

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
