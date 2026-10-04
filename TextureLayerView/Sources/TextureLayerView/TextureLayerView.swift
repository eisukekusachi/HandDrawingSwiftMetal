//
//  Created by Eisuke Kusachi
//

import SwiftUI

public struct TextureLayerView: View {

    @ObservedObject private var viewModel: TextureLayerViewModel

    public init(
        textureLayers: any TextureLayersProtocol,
        onClose: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self._viewModel = .init(
            wrappedValue: TextureLayerViewModel(
                textureLayers: textureLayers,
                onClose: onClose,
                onError: onError
            )
        )
    }

    public var body: some View {
        VStack {
            TextureLayerToolbar(
                viewModel: viewModel
            )

            ReversedTextureLayerListView(
                viewModel: viewModel,
                onMove: { source, destination in
                    viewModel.onMoveLayer(source: source, destination: destination)
                }
            )

            SliderWithStepper(
                title: "Alpha",
                value: Binding(
                    get: { viewModel.currentAlpha },
                    set: { viewModel.onChangeCurrentAlpha($0) }
                ),
                onEditingChanged: { dragging in
                    viewModel.onAlphaSliderDragging(dragging)
                }
            )
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
        }
    }

    /// Updates the alpha slider without changing the selected layer.
    public func updateAlpha(_ alpha: Int) {
        viewModel.setCurrentAlpha(alpha)
    }
}

@MainActor
private struct PreviewView: View {
    private let textureLayers: PreviewTextureLayers = {
        let layers: [TextureLayerItem] = [
            .init(id: LayerId(), title: "Layer0", alpha: 255, isVisible: true),
            .init(id: LayerId(), title: "Layer1", alpha: 200, isVisible: true),
            .init(id: LayerId(), title: "Layer2", alpha: 150, isVisible: true),
            .init(id: LayerId(), title: "Layer3", alpha: 100, isVisible: true),
            .init(id: LayerId(), title: "Layer4", alpha: 50, isVisible: true)
        ]
        return PreviewTextureLayers(
            layers: layers,
            selectedLayerId: layers[3].id
        )
    }()
    var body: some View {
        TextureLayerView(
            textureLayers: textureLayers
        )
        .frame(width: 320, height: 315)
    }
}

#Preview("Light") {
    PreviewView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewView()
        .preferredColorScheme(.dark)
}

@MainActor
final class PreviewTextureLayers: TextureLayersProtocol {
    @Published var layers: [TextureLayerItem]
    @Published var selectedLayerId: LayerId?

    init(
        layers: [TextureLayerItem],
        selectedLayerId: LayerId? = nil
    ) {
        self.layers = layers
        self.selectedLayerId = selectedLayerId
    }

    func addLayer() async throws {}

    func removeLayer(id: LayerId) async throws -> Bool { false }

    func renameLayer(id: LayerId, title: String) throws {}

    func moveLayers(from source: IndexSet, to destination: Int) throws {}

    func selectLayer(id: LayerId) throws {
        selectedLayerId = id
    }

    func setVisibility(id: LayerId, isVisible: Bool) throws {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index] = layers[index].updated(isVisible: isVisible)
    }

    func setAlpha(id: LayerId, alpha: Int) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index] = layers[index].updated(alpha: alpha)
    }

    func setAlphaSliderDragging(_ isDragging: Bool) {}
}
