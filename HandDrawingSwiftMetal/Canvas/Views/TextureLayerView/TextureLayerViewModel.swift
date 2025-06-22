//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import MetalKit

/// Manage texture layers using `CanvasState` and `TextureLayerRepository`
final class TextureLayerViewModel: ObservableObject {

    @Published var selectedLayerAlpha: Int = 0

    @Published var isSliderHandleDragging: Bool = false

    var selectedLayer: TextureLayerModel? {
        canvasState.selectedLayer
    }

    var textureSize: CGSize {
        canvasState.textureSize
    }

    var newInsertIndex: Int {
        (canvasState.selectedIndex ?? 0) + 1
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        textureLayerRepository?.thumbnail(uuid)
    }

    @Published private(set) var layers: [TextureLayerModel] = []

    @Published private(set) var selectedLayerId: UUID? {
        didSet {
            if let selectedLayerId {
                updateSliderHandlePosition(selectedLayerId)
            }
        }
    }

    private var canvasState: CanvasState

    private var textureLayerRepository: TextureLayerRepository!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var cancellables = Set<AnyCancellable>()

    init(
        canvasState: CanvasState,
        textureLayerRepository: TextureLayerRepository
    ) {
        self.canvasState = canvasState
        self.textureLayerRepository = textureLayerRepository

        canvasState.$layers.assign(to: \.layers, on: self)
            .store(in: &cancellables)

        canvasState.$selectedLayerId.assign(to: \.selectedLayerId, on: self)
            .store(in: &cancellables)

        textureLayerRepository.objectWillChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        $selectedLayerAlpha
            .sink { [weak self] value in
                guard
                    let selectedLayerId = self?.selectedLayerId
                else { return }

                self?.updateLayer(
                    id: selectedLayerId,
                    alpha: value
                )
            }
            .store(in: &cancellables)

        $isSliderHandleDragging
            .sink { _ in }
            .store(in: &cancellables)
    }

}

// MARK: CRUD
extension TextureLayerViewModel {

    func insertLayer(textureSize: CGSize, at index: Int) {
        let newTextureLayer: TextureLayerModel = .init(title: TimeStampFormatter.currentDate())
        let newTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: self.device)

        textureLayerRepository
            .addTexture(newTexture, using: newTextureLayer.id)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished: break
                    case .failure: break
                    }
                },
                receiveValue: { [weak self] result in
                    guard let `self` else { return }

                    self.canvasState.layers.insert(newTextureLayer, at: index)
                    self.canvasState.selectedLayerId = newTextureLayer.id

                    self.canvasState.fullCanvasUpdateSubject.send(())
                }
            )
            .store(in: &cancellables)
    }

    func removeLayer() {
        guard
            let selectedIndex = canvasState.selectedIndex,
            canvasState.layers.count > 1, canvasState.layers.indices.contains(selectedIndex)
        else { return }

        let layerId = canvasState.layers[selectedIndex].id

        textureLayerRepository
            .removeTexture(layerId)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished: break
                    case .failure: break
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let `self` else { return }

                    self.canvasState.layers.remove(at: selectedIndex)
                    self.canvasState.selectedLayerId = self.canvasState.layers[max(selectedIndex - 1, 0)].id

                    self.canvasState.fullCanvasUpdateSubject.send(())
                }
            )
            .store(in: &cancellables)
    }

    /// Sort TextureLayers's `layers` based on the values received from `List`
    func moveLayer(
        fromListOffsets: IndexSet,
        toListOffset: Int
    ) {
        // Since `textureLayers` and `List` have reversed orders,
        // reverse the array, perform move operations, and then reverse it back
        canvasState.layers.reverse()
        canvasState.layers.move(
            fromOffsets: fromListOffsets,
            toOffset: toListOffset
        )
        canvasState.layers.reverse()

        canvasState.fullCanvasUpdateSubject.send(())
    }

    func selectLayer(_ uuid: UUID) {
        canvasState.selectedLayerId = uuid
        canvasState.fullCanvasUpdateSubject.send(())
    }

    func updateLayer(
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard let selectedIndex = canvasState.layers.map({ $0.id }).firstIndex(of: id) else { return }

        if let title {
            canvasState.layers[selectedIndex].title = title
        }
        if let isVisible {
            canvasState.layers[selectedIndex].isVisible = isVisible

            // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
            canvasState.fullCanvasUpdateSubject.send(())
        }
        if let alpha {
            canvasState.layers[selectedIndex].alpha = alpha

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            canvasState.canvasUpdateSubject.send(())
        }
    }

}

extension TextureLayerViewModel {

    private func updateSliderHandlePosition(_ layerId: UUID) {
        guard let layer = canvasState.layer(layerId) else { return }
        selectedLayerAlpha = layer.alpha
    }

}

enum TextureLayerError: Error {
    case indexOutOfBounds
    case minimumLayerRequired
    case failedToUnwrap
}
