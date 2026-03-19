//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import CanvasView
import Combine
import UIKit

@MainActor
public final class TextureLayerViewModel: ObservableObject {

    @Published public var currentAlpha: Int = 0

    @Published public var isAlphaSliderDragging: Bool = false

    public var selectedLayer: TextureLayerItem? {
        textureLayers?.selectedLayer
    }

    @Published private(set) var textureLayers: TextureLayersState?

    private(set) var defaultBackgroundColor: UIColor = .white
    private(set) var selectedBackgroundColor: UIColor = .black

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            updateCurrentAlpha()
        }
    }

    private let dependencies: TextureLayerViewDependencies?

    private var cancellables = Set<AnyCancellable>()

    public init(
        dependencies: TextureLayerViewDependencies?
    ) {
        self.dependencies = dependencies
    }

    public func update(
        _ textureLayers: TextureLayersState
    ) {
        self.textureLayers = textureLayers

        // Avoid multiple subscriptions
        cancellables.removeAll()

        self.textureLayers?.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        Task {
            for layer in textureLayers.layers {
                let layerId: LayerId = layer.id
                let texture = try? await self.dependencies?.textureLayersDocumentsRepository.duplicatedTexture(layerId)
                textureLayers.updateThumbnail(layerId, texture: texture?.texture)
            }
        }
    }

    public func initialize(
        textureLayers: TextureLayersState
    ) {
        self.textureLayers = textureLayers

        updateCurrentAlpha()
    }

    private func bindData() {
        // Avoid multiple subscriptions
        cancellables.removeAll()

        // Bind the alpha slider
        $currentAlpha
            .sink { [weak self] alpha in
                guard
                    let `self`,
                    self.isAlphaSliderDragging,
                    let textureLayers = self.textureLayers,
                    let selectedLayerId = self.selectedLayerId
                else { return }

                textureLayers.updateAlpha(
                    selectedLayerId,
                    alpha: Int(alpha)
                )

                // Only the alpha of the selected layer can be changed, so other layers will not be updated
                // textureLayers.requestCanvasUpdate()
            }
            .store(in: &cancellables)

        $isAlphaSliderDragging
            .sink { [weak self] isDragging in
                if isDragging {
                    self?.textureLayers?.beginAlphaChange()
                } else {
                    self?.textureLayers?.endAlphaChange()
                }
            }
            .store(in: &cancellables)
    }
}

public extension TextureLayerViewModel {

    func isSelected(_ id: UUID) -> Bool {
        textureLayers?.selectedLayer?.id == id
    }

    func onTapInsertButton() {
        guard
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex
        else { return }

        Task {
            do {
                try await textureLayers.addNewLayer(
                    at: AddLayerIndex.insertIndex(selectedIndex: selectedIndex)
                )
                // fullCanvasUpdateRequestedSubject.send()
            } catch {
                Logger.error(error)
            }
        }
    }

    func onTapDeleteButton() {
        guard
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex,
            textureLayers.layerCount > 1
        else { return }

        Task {
            try await textureLayers.removeLayer(layerIndexToDelete: selectedIndex)
            // fullCanvasUpdateRequestedSubject.send()
        }
    }

    func onTapTitleButton(_ id: UUID, title: String) {
        textureLayers?.updateTitle(id, title: title)
    }

    func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        guard let textureLayers else { return }

        textureLayers.updateVisibility(id, isVisible: isVisible)

        // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
        // fullCanvasUpdateRequestedSubject.send()
    }

    func onTapCell(_ id: UUID) {
        textureLayers?.selectLayer(id)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        guard let textureLayers else { return }

        Task {
            textureLayers.moveLayer(
                indices: .init(
                    sourceIndexSet: source,
                    destinationIndex: destination
                )
            )
            // fullCanvasUpdateRequestedSubject.send()
        }
    }
}

extension TextureLayerViewModel {

    private func updateCurrentAlpha() {
        if let selectedLayerId, let layer = textureLayers?.layer(selectedLayerId) {
            currentAlpha = layer.alpha
        }
    }
}
