//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import CanvasView
import SwiftUI

public struct TextureLayerView: View {

    @State private var isTextFieldPresented: Bool = false
    @State private var textFieldTitle: String = ""

    private let buttonThrottle = ButtonThrottle()

    private let range: ClosedRange<Int> = 0 ... 255

    private let buttonSize: CGFloat = 20

    @ObservedObject private var viewModel: TextureLayerViewModel

    public init(
        viewModel: TextureLayerViewModel
    ) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if let canvasState = viewModel.canvasState {
            VStack {
                toolbar(viewModel)

                TextureLayerListView(
                    viewModel: viewModel,
                    canvasState: canvasState
                )

                TwoRowsSliderView(
                    value: $viewModel.alphaSliderValue,
                    title: "Alpha",
                    range: range
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
        } else {
            EmptyView()
        }
    }
}

public extension TextureLayerView {

    private func toolbar(
        _ viewModel: TextureLayerViewModel
    ) -> some View {
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

#Preview {
    PreviewView()
}

private struct PreviewView: View {
    let canvasState = CanvasState()
    let configuration: TextureLayerConfiguration

    init() {
        canvasState.initialize(
            configuration: .init(
                textureSize: .init(width: 44, height: 44),
                layerIndex: 1,
                layers: [
                    .init(textureName: UUID().uuidString, title: "Layer0", alpha: 255),
                    .init(textureName: UUID().uuidString, title: "Layer1", alpha: 200),
                    .init(textureName: UUID().uuidString, title: "Layer2", alpha: 150),
                    .init(textureName: UUID().uuidString, title: "Layer3", alpha: 100),
                    .init(textureName: UUID().uuidString, title: "Layer4", alpha: 50),
                ]
            )
        )

        configuration = .init(
            canvasState: canvasState,
            textureRepository: MockTextureRepository(),
            undoStack: nil
        )
    }
    var body: some View {
        TextureLayerView(
            viewModel: TextureLayerViewModel()
        )
        .frame(width: 320, height: 300)
    }
}
