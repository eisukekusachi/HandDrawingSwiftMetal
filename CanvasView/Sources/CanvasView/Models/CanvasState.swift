//
//  CanvasState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// Manage the state of the canvas
public final class CanvasState: ObservableObject, @unchecked Sendable {

    /// Subject to publish updates for the canvas
    public let canvasUpdateSubject = PassthroughSubject<Void, Never>()

    /// Subject to publish updates for the entire canvas, including all textures
    public let fullCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    @Published public var layers: [TextureLayerModel] = []

    @Published public var selectedLayerId: UUID?

    /// A name of the file to be saved
    @Published private(set) var projectName: String = Calendar.currentDate

    @Published private(set) var textureSize: CGSize = CanvasState.defaultTextureSize

    @Published private(set) var backgroundColor: UIColor = .white

    private static let defaultTextureSize: CGSize = .init(width: 768, height: 1024)

    public init() {}

    public func initialize(
        configuration: CanvasResolvedConfiguration,
        textureRepository: TextureRepository? = nil
    ) {
        self.projectName = configuration.projectName

        self.textureSize = configuration.textureSize

        self.layers = configuration.layers.map {
            .init(item: $0, thumbnail: nil)
        }

        self.selectedLayerId = configuration.selectedLayerId

        Task {
            let results = try await textureRepository?.copyTextures(uuids: layers.map { $0.id })
            await updateAllThumbnails(results ?? [])
        }
    }
}

public extension CanvasState {

    var currentTextureSize: CGSize {
        textureSize
    }

    var selectedLayer: TextureLayerModel? {
        guard let selectedLayerId else { return nil }
        return layers.first(where: { $0.id == selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    func layer(_ layerId: UUID) -> TextureLayerModel? {
        layers.first(where: { $0.id == layerId })
    }
}

public extension CanvasState {

    func addLayer(newTextureLayer textureLayer: TextureLayerModel, at index: Int) {
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

    func updateLayer(newTextureLayer: TextureLayerModel) {
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
