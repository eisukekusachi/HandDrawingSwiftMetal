//
//  TextureLayerToolbar.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import CanvasView
import SwiftUI

public struct TextureLayerToolbar: View {

    private let buttonThrottle = ButtonThrottle()

    private let buttonSize: CGFloat = 20

    @ObservedObject private var viewModel: TextureLayerViewModel

    @State private var isTextFieldPresented: Bool = false
    @State private var textFieldTitle: String = ""

    init(viewModel: TextureLayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack {
            Button(
                action: {
                    buttonThrottle.throttle(id: "insertLayer") {
                        Task { @MainActor in
                            viewModel.onTapInsertButton()
                        }
                    }
                },
                label: {
                    Image(systemName: "plus.circle")
                        .buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    buttonThrottle.throttle(id: "removeLayer") {
                        Task { @MainActor in
                            viewModel.onTapDeleteButton()
                        }
                    }
                },
                label: {
                    Image(systemName: "minus.circle")
                        .buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textFieldTitle = viewModel.selectedLayer?.title ?? ""
                    isTextFieldPresented = true
                },
                label: {
                    Image(systemName: "pencil")
                        .buttonModifier(diameter: buttonSize)
                }
            )
            .alert("Enter a title", isPresented: $isTextFieldPresented) {
                TextField("Enter a title", text: $textFieldTitle)
                Button("OK", action: {
                    guard let selectedLayer = viewModel.selectedLayer else { return }
                    viewModel.onTapTitleButton(id: selectedLayer.id, title: textFieldTitle)
                })
                Button("Cancel", action: {})
            }
            Spacer()
        }
        .padding(8)
    }
}

private extension Image {
    func buttonModifier(diameter: CGFloat, _ uiColor: UIColor = .systemBlue) -> some View {
        self
            .resizable()
            .scaledToFit()
            .frame(width: diameter, height: diameter)
            .foregroundColor(Color(uiColor: uiColor))
    }
}

private struct PreviewView: View {
    let canvasState = CanvasState()
    let textureLayerConfiguration: TextureLayerConfiguration
    let viewModel = TextureLayerViewModel()

    init() {
        let layers: [TextureLayerItem] = [
            .init(
                textureName: UUID().uuidString,
                title: "Layer0",
                alpha: 255
            ),
            .init(textureName: UUID().uuidString, title: "Layer1", alpha: 200),
            .init(textureName: UUID().uuidString, title: "Layer2", alpha: 150),
            .init(textureName: UUID().uuidString, title: "Layer3", alpha: 100),
            .init(textureName: UUID().uuidString, title: "Layer4", alpha: 50),
        ]

        let configuration: CanvasResolvedConfiguration = .init(
            projectName: "",
            textureSize: .zero,
            layerIndex: 0,
            layers: layers.map { .init(item: $0, thumbnail: nil) },
            brushColors: [],
            brushIndex: 0,
            brushDiameter: 0,
            eraserAlphas: [],
            eraserIndex: 0,
            eraserDiameter: 0
        )

        canvasState.initialize(
            configuration: configuration
        )

        textureLayerConfiguration = .init(
            canvasState: canvasState,
            textureRepository: MockTextureRepository(),
            undoStack: nil
        )

        viewModel.initialize(configuration: textureLayerConfiguration)
    }
    var body: some View {
        TextureLayerToolbar(
            viewModel: viewModel
        )
        .frame(width: 320, height: 300)
    }
}

#Preview {
    PreviewView()
}
