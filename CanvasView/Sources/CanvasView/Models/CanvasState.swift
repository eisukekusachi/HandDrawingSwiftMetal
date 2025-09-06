//
//  CanvasState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// Manage the state of the canvas
public final class CanvasState: ObservableObject {

    /// Subject to publish updates for the canvas
    public let canvasUpdateSubject = PassthroughSubject<Void, Never>()

    /// Subject to publish updates for the entire canvas, including all textures
    public let fullCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    @Published public var layers: [TextureLayerItem] = []

    @Published public var selectedLayerId: UUID?

    /// A name of the file to be saved
    @Published private(set) var projectName: String = Calendar.currentDate

    @Published private(set) var textureSize: CGSize = .init(width: 768, height: 1024)

    @Published private(set) var backgroundColor: UIColor = .white

    public init() {}

    @MainActor
    public func initialize(
        configuration: CanvasResolvedConfiguration,
        textureRepository: TextureRepository? = nil
    ) async {
        self.projectName = configuration.projectName

        self.textureSize = configuration.textureSize

        self.layers = configuration.layers.map {
            .init(
                id: $0.id,
                title: $0.title,
                alpha: $0.alpha,
                isVisible: $0.isVisible,
                thumbnail: nil
            )
        }

        self.selectedLayerId = configuration.selectedLayerId

        Task {
            let results = try await textureRepository?.copyTextures(uuids: layers.map { $0.id })
            self.updateAllThumbnails(results ?? [])
        }
    }
}

public extension CanvasState {

    // Add a computed property for cross-package access
    var currentTextureSize: CGSize {
        textureSize
    }

    var selectedLayer: TextureLayerItem? {
        guard let selectedLayerId else { return nil }
        return layers.first(where: { $0.id == selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    func layer(_ layerId: UUID) -> TextureLayerItem? {
        layers.first(where: { $0.id == layerId })
    }
}

public extension CanvasState {

    func addLayer(newTextureLayer textureLayer: TextureLayerItem, at index: Int) {
        self.layers.insert(textureLayer, at: index)
        self.selectedLayerId = textureLayer.id
    }

    func removeLayer(layerIdToDelete: UUID, newLayerId: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerIdToDelete }) else { return }
        self.layers.remove(at: index)
        self.selectedLayerId = newLayerId
    }

    func moveLayer(
        indices: MoveLayerIndices,
        selectedLayerId: UUID
    ) {
        self.layers.move(fromOffsets: indices.sourceIndexSet, toOffset: indices.destinationIndex)
        self.selectedLayerId = selectedLayerId
    }

    func updateLayer(newTextureLayer: TextureLayerItem) {
        guard let index = layers.firstIndex(where: { $0.id == newTextureLayer.id }) else { return }
        self.layers[index] = newTextureLayer
        self.selectedLayerId = newTextureLayer.id
    }

    @MainActor
    func updateThumbnail(_ identifiedTexture: IdentifiedTexture) {
        guard let index = layers.firstIndex(where: { $0.id == identifiedTexture.uuid }) else { return }
        self.layers[index].thumbnail = identifiedTexture.texture.makeThumbnail()
    }

    @MainActor
    func updateAllThumbnails(_ identifiedTextures: [IdentifiedTexture]) {
        for identifiedTexture in identifiedTextures {
            updateThumbnail(identifiedTexture)
        }
    }
}
