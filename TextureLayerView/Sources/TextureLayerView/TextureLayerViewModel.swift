//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import UIKit

@MainActor
public final class TextureLayerViewModel: ObservableObject {

    @Published public var currentAlpha: Int = 0

    @Published public var isAlphaSliderDragging: Bool = false

    public let onLayersChanged: ((TextureLayerEvent) -> Void)?

    public var selectedLayer: TextureLayerItem? {
        textureLayers?.selectedLayer
    }

    @Published private(set) var textureLayers: TextureLayersState?

    private let dependencies: TextureLayerViewDependencies?

    private var cancellables = Set<AnyCancellable>()

    public init(
        dependencies: TextureLayerViewDependencies? = nil,
        onLayersChanged: ((TextureLayerEvent) -> Void)? = nil
    ) {
        self.dependencies = dependencies ?? .init()
        self.onLayersChanged = onLayersChanged
    }

    public func update(
        _ textureLayers: TextureLayersState,
        device: MTLDevice? = nil
    ) {
        self.textureLayers = textureLayers

        // Update the thumbails
        Task { [weak self] in
            for layer in textureLayers.layers {
                guard let device else { return }
                let layerId: LayerId = layer.id
                let texture = try? await self?.dependencies?.textureLayersDocumentsRepository.duplicatedTexture(
                    layerId,
                    device: device
                )
                textureLayers.updateThumbnail(layerId, texture: texture?.texture)
            }
        }

        // Update the alpha slider handle position
        self.updateCurrentAlpha()

        // Avoid multiple subscriptions
        cancellables.removeAll()

        self.textureLayers?.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

public extension TextureLayerViewModel {

    func isSelected(_ id: UUID) -> Bool {
        textureLayers?.selectedLayer?.id == id
    }

    func onTapInsertButton(device: MTLDevice?) async throws {
        guard
            let device,
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex,
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureLayers.textureSize.width),
                height: Int(textureLayers.textureSize.height),
                with: device
            )
        else { return }

        let layer: TextureLayerModel = .init(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )
        try await textureLayers.addLayer(
            layer: layer,
            thumbnail: newTexture.makeThumbnail(),
            at: AddLayerIndex.insertIndex(selectedIndex: selectedIndex)
        )
        try await dependencies?.textureLayersDocumentsRepository
            .addTexture(
                texture: newTexture,
                id: layer.id,
                device: device
            )
        onLayersChanged?(.addLayer)
    }

    func onTapDeleteButton() async throws {
        guard
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex,
            let selectedId = textureLayers.selectedLayer?.id,
            textureLayers.layerCount > 1
        else { return }

        try await textureLayers.removeLayer(
            layerIndexToDelete: selectedIndex
        )
        try dependencies?.textureLayersDocumentsRepository
            .removeTexture(
                selectedId
            )
        onLayersChanged?(.removeLayer)
    }

    func onTapTitleButton(_ id: UUID, title: String) {
        textureLayers?.updateTitle(id, title: title)
    }

    func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        textureLayers?.updateVisibility(id, isVisible: isVisible)
        onLayersChanged?(.changeVisibility)
    }

    func onTapCell(_ id: UUID) {
        textureLayers?.selectLayer(id)
        updateCurrentAlpha()
        onLayersChanged?(.selectLayer)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        textureLayers?.moveLayer(
            indices: .init(
                sourceIndexSet: source,
                destinationIndex: destination
            )
        )
        onLayersChanged?(.moveLayer)
    }

    func onChangeCurrentAlpha(_ alpha: Int) {
        guard let selectedLayerId = textureLayers?.selectedLayer?.id else { return }
        textureLayers?.updateAlpha(selectedLayerId, alpha: alpha)
        updateCurrentAlpha()
        onLayersChanged?(.changeLayerAlpha)
    }
}

extension TextureLayerViewModel {

    private func updateCurrentAlpha() {
        guard
            let selectedLayerId = textureLayers?.selectedLayer?.id,
            let layer = textureLayers?.layer(selectedLayerId),
            currentAlpha != layer.alpha
        else { return }

        currentAlpha = layer.alpha
    }
}
