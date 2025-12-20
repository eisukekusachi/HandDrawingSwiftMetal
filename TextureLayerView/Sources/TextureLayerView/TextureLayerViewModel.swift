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

    @Published private(set) var layers: [TextureLayerItem] = []

    @Published public var currentAlpha: Int = 0

    @Published public var isDragging: Bool = false

    public var selectedLayer: TextureLayerItem? {
        textureLayers?.selectedLayer
    }

    private(set) var textureLayers: (any TextureLayersProtocol)?

    private(set) var defaultBackgroundColor: UIColor = .white
    private(set) var selectedBackgroundColor: UIColor = .black

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            if let selectedLayerId, let layer = textureLayers?.layer(selectedLayerId) {
                currentAlpha = layer.alpha
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func initialize(
        textureLayers: any TextureLayersProtocol
    ) {
        self.textureLayers = textureLayers
        subscribe()
    }

    private func subscribe() {
        // Bind the alpha slider
        $currentAlpha
            .sink { [weak self] alpha in
                guard
                    let `self`,
                    let textureLayers = self.textureLayers,
                    let selectedLayerId = self.selectedLayerId
                else { return }

                textureLayers.updateAlpha(
                    selectedLayerId,
                    alpha: Int(alpha)
                )

                // Only the alpha of the selected layer can be changed, so other layers will not be updated
                textureLayers.requestCanvasUpdate()
            }
            .store(in: &cancellables)

        $isDragging
            .sink { [weak self] isDragging in
                if isDragging {
                    self?.textureLayers?.beginAlphaChange()
                } else {
                    self?.textureLayers?.endAlphaChange()
                }
            }
            .store(in: &cancellables)

        textureLayers?.selectedLayerIdPublisher
            .sink { [weak self] value in
                self?.selectedLayerId = value
            }
            .store(in: &cancellables)

        textureLayers?.layersPublisher
            .sink { [weak self] value in
                self?.layers = value
            }
            .store(in: &cancellables)

        textureLayers?.alphaPublisher
            .removeDuplicates()
            .filter { [weak self] alpha in
                self?.currentAlpha != alpha
            }
            .sink { [weak self] alpha in
                self?.currentAlpha = alpha
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
                textureLayers.requestFullCanvasUpdate()
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
            textureLayers.requestFullCanvasUpdate()
        }
    }

    func onTapTitleButton(_ id: UUID, title: String) {
        textureLayers?.updateTitle(id, title: title)
    }

    func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        guard let textureLayers else { return }

        textureLayers.updateVisibility(id, isVisible: isVisible)

        // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
        textureLayers.requestFullCanvasUpdate()
    }

    func onTapCell(_ id: UUID) {
        guard let textureLayers else { return }

        textureLayers.selectLayer(id)
        textureLayers.requestFullCanvasUpdate()
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
            textureLayers.requestFullCanvasUpdate()
        }
    }
}
