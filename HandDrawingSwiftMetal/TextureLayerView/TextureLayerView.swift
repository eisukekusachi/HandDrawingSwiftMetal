//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import CanvasView
import SwiftUI

struct TextureLayerView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    @ObservedObject var roundedRectangleWithArrow: RoundedRectangleWithArrow

    @State private var isTextFieldPresented: Bool = false
    @State private var textFieldTitle: String = ""

    private let buttonThrottle = ButtonThrottle()

    private let range = 0 ... 255

    var body: some View {
        ZStack {
            roundedRectangleWithArrow.viewWithTopArrow(
                arrowSize: roundedRectangleWithArrow.arrowSize,
                roundedCorner: roundedRectangleWithArrow.roundedCorner
            )

            VStack {
                toolbar(
                    viewModel,
                    changeTitle: { layer, title in
                        viewModel.onTapTitleButton(id: layer.id, title: title)
                    }
                )

                TextureLayerListView(
                    viewModel: viewModel,
                    canvasState: viewModel.canvasState
                )

                TwoRowsSliderView(
                    sliderValue: viewModel.alphaSliderValue,
                    title: "Alpha",
                    range: range
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(roundedRectangleWithArrow.edgeInsets())
        }
    }

}

extension TextureLayerView {

    private func toolbar(
        _ viewModel: TextureLayerViewModel,
        changeTitle: ((TextureLayerModel, String) -> Void)? = nil
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    buttonThrottle.throttle(id: "insertLayer") {
                        viewModel.onTapInsertButton()
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
                        viewModel.onTapDeleteButton()
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
                    changeTitle?(selectedLayer, textFieldTitle)
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
    let canvasState = CanvasState(
        .init(
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
    let configuration: TextureLayerConfiguration

    @StateObject var roundedRectangle = RoundedRectangleWithArrow()

    init() {
        configuration = .init(
            canvasState: canvasState,
            textureLayerRepository: MockTextureLayerRepository(),
            undoStack: nil
        )
    }
    var body: some View {
        TextureLayerView(
            viewModel: .init(configuration: configuration),
            roundedRectangleWithArrow: roundedRectangle
        )
        .frame(width: 320, height: 300)
    }

}
