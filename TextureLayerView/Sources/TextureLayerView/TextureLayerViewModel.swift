//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import CanvasView
import Combine
import MetalKit

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

    private var textureRepository: TextureRepository!

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
                    id: selectedLayerId,
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
    }
}

public extension TextureLayerViewModel {

    func isSelected(_ uuid: UUID) -> Bool {
        textureLayers?.selectedLayer?.id == uuid
    }

    func onTapInsertButton() {
        guard
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex,
            let device: MTLDevice = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeTexture(
                width: Int(textureLayers.textureSize.width),
                height: Int(textureLayers.textureSize.height),
                with: device
            )
        else { return }

        let layer: TextureLayerItem = .init(
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true,
            thumbnail: texture.makeThumbnail()
        )
        let index = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)

        Task {
            do {
                try await textureLayers.addLayer(
                    layer: layer,
                    texture: texture,
                    at: index
                )
            } catch {

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
        }
    }

    func onTapTitleButton(id: UUID, title: String) {
        textureLayers?.updateTitle(id: id, title: title)
    }

    func onTapVisibleButton(id: UUID, isVisible: Bool) {
        guard let textureLayers else { return }

        textureLayers.updateVisibility(id: id, isVisible: isVisible)

        // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
        textureLayers.requestFullCanvasUpdate()
    }

    func onTapCell(id: UUID) {
        textureLayers?.selectLayer(id: id)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        Task {
            textureLayers?.moveLayer(
                indices: .init(
                    sourceIndexSet: source,
                    destinationIndex: destination
                )
            )
        }
    }
}
