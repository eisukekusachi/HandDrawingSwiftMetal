//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import MetalKit

/// Manages the textures used for rendering
final class TextureLayers: ObservableObject {

    @Published var layers: [TextureLayerModel] = []

    @Published private var selectedLayerId: UUID?

    var selectedLayer: TextureLayerModel? {
        guard let selectedLayerId else { return nil }
        return layers.first(where: { $0.id == selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    var didFinishInitializationPublisher: AnyPublisher<CGSize, Never> {
        didFinishInitializationSubject.eraseToAnyPublisher()
    }
    private let didFinishInitializationSubject = PassthroughSubject<CGSize, Never>()

    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> {
        updateCanvasAfterTextureLayerUpdatesSubject.eraseToAnyPublisher()
    }
    var updateCanvasPublisher: AnyPublisher<Void, Never> {
        updateCanvasSubject.eraseToAnyPublisher()
    }
    private let updateCanvasAfterTextureLayerUpdatesSubject = PassthroughSubject<Void, Never>()
    private let updateCanvasSubject = PassthroughSubject<Void, Never>()

    let initializeWithModelSubject = PassthroughSubject<CanvasModel, Never>()
    let initializeWithTextureSizeSubject = PassthroughSubject<CGSize, Never>()

    var drawableTextureSize: CGSize = MTLRenderer.minimumTextureSize {
        didSet {
            if drawableTextureSize < MTLRenderer.minimumTextureSize {
                drawableTextureSize = MTLRenderer.minimumTextureSize
            }
        }
    }

    private var textureRepository: (any TextureRepository)!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var cancellables = Set<AnyCancellable>()

    init(
        layers: [TextureLayerModel] = [],
        textureRepository: (any TextureRepository) = SingletonTextureInMemoryRepository.shared
    ) {
        self.layers = layers

        self.textureRepository = textureRepository

        initializeWithModelSubject
            .sink { [weak self] model in
                self?.initializeWithModel(model)
            }
            .store(in: &cancellables)

        initializeWithTextureSizeSubject
            .sink { [weak self] textureSize in
                self?.initializeWithTextureSize(textureSize)
            }
            .store(in: &cancellables)
    }

    /// Attempts to restore layers from a given `CanvasModel`
    /// If the model is invalid, initialization is performed using the given texture size
    func restoreLayers(from model: CanvasModel, drawableSize: CGSize) {
        drawableTextureSize = drawableSize

        textureRepository?.hasAllTextures(for: model.layers.map { $0.id })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] allExist in
                guard let `self` else { return }
                if allExist {
                    self.initializeWithModelSubject.send(model)
                } else {
                    self.initializeWithTextureSizeSubject.send(
                        model.getTextureSize(drawableTextureSize: self.drawableTextureSize)
                    )
                }
            })
            .store(in: &cancellables)
    }

    private func initializeWithModel(_ model: CanvasModel) {
        guard
            let textureSize = model.textureSize,
            textureSize > MTLRenderer.minimumTextureSize
        else { return }

        layers.removeAll()
        layers = model.layers
        selectedLayerId = layers[model.layerIndex].id

        didFinishInitializationSubject.send(textureSize)
    }

    private func initializeWithTextureSize(_ textureSize: CGSize) {
        guard textureSize > MTLRenderer.minimumTextureSize else { return }

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate
        )

        layers.removeAll()
        layers.insert(layer, at: 0)
        selectedLayerId = layer.id

        textureRepository?.initTexture(
            uuid: layer.id,
            textureSize: textureSize
        )
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished: break
            case .failure: break
            }
        }, receiveValue: { [weak self] in
            self?.didFinishInitializationSubject.send(textureSize)
        })
        .store(in: &cancellables)
    }

}

extension TextureLayers {

    func insertLayer(textureSize: CGSize, at index: Int) {
        guard let textureRepository else { return }
        let device = self.device

        addNewLayerPublisher(at: index)
            .flatMap { textureLayerId in
                textureRepository.updateTexture(
                    texture: MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
                    for: textureLayerId
                )
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] newLayerTextureId in
                self?.selectedLayerId = newLayerTextureId
                self?.updateCanvasAfterTextureLayerUpdatesSubject.send(())
            })
            .store(in: &cancellables)
    }

    func removeLayer() {
        guard
            let textureRepository,
            let selectedLayerId = selectedLayer?.id,
            let index = layers.firstIndex(where: { $0.id == selectedLayerId })
        else { return }

        let newSelectedLayerId = layers[max(index - 1, 0)].id

        removeLayerPublisher(from: index)
            .flatMap { removedTextureId -> AnyPublisher<UUID, Never> in
                textureRepository.removeTexture(removedTextureId)
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] _ in
                self?.selectedLayerId = newSelectedLayerId
                self?.updateCanvasAfterTextureLayerUpdatesSubject.send(())
            })
            .store(in: &cancellables)
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        textureRepository?.getThumbnail(uuid)
    }

    func selectLayer(_ uuid: UUID) {
        selectedLayerId = uuid
        updateCanvasAfterTextureLayerUpdatesSubject.send(())
    }

}

// MARK: CRUD
extension TextureLayers {

    var newIndex: Int {
        (selectedIndex ?? 0) + 1
    }

    func addLayer(at index: Int) -> UUID? {
        guard index >= 0 && index <= layers.count else { return nil }

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate
        )
        layers.insert(layer, at: index)
        return layer.id
    }
    func removeLayer(from index: Int) -> UUID? {
        guard layers.count > 1, layers.indices.contains(index) else { return nil }

        let removedLayerId = layers[index].id
        layers.remove(at: index)
        return removedLayerId
    }

    /// Sort TextureLayers's `layers` based on the values received from `List`
    func moveLayer(
        fromListOffsets: IndexSet,
        toListOffset: Int
    ) {
        // Since `textureLayers` and `List` have reversed orders,
        // reverse the array, perform move operations, and then reverse it back
        layers.reverse()
        layers.move(
            fromOffsets: fromListOffsets,
            toOffset: toListOffset
        )
        layers.reverse()

        updateCanvasAfterTextureLayerUpdatesSubject.send(())
    }

    func updateLayer(
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }

        if let title {
            layers[index].title = title
        }
        if let isVisible {
            layers[index].isVisible = isVisible

            // The visibility of the layers can be changed, so other layers will be updated
            updateCanvasAfterTextureLayerUpdatesSubject.send(())
        }
        if let alpha {
            layers[index].alpha = alpha

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            updateCanvasSubject.send(())
        }
    }

    func updateThumbnail(_ selectedTexture: MTLTexture) {
        guard let selectedLayerId else { return }

        textureRepository?.setThumbnail(
            texture: selectedTexture,
            for: selectedLayerId
        )

        objectWillChange.send()
    }

}

// MARK: Publishers
extension TextureLayers {

    private func addNewLayerPublisher(at index: Int) -> AnyPublisher<UUID, Error> {
        Just(index)
            .tryMap { [weak self] index in
                guard let newLayerId = self?.addLayer(at: index) else {
                    throw TextureLayerError.indexOutOfBounds
                }
                return newLayerId
            }
            .eraseToAnyPublisher()
    }
    func removeLayerPublisher(from index: Int) -> AnyPublisher<UUID, Error> {
        Just(index)
            .tryMap { [weak self] index in
                guard let removeLayerId = self?.removeLayer(from: index) else {
                    throw TextureLayerError.minimumLayerRequired
                }
                return removeLayerId
            }
            .eraseToAnyPublisher()
    }

}

enum TextureLayerError: Error {
    case indexOutOfBounds
    case minimumLayerRequired
    case failedToUnwrap
}
