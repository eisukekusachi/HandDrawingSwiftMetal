//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerView: View {

    @ObservedObject var canvasState: CanvasState
    @ObservedObject var textureLayers: TextureLayers

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    var roundedRectangleWithArrow: RoundedRectangleWithArrow

    var didTapLayer: ((TextureLayerModel) -> Void)? = nil
    var didTapRemoveButton: (() -> Void)? = nil
    var didTapVisibility: ((TextureLayerModel, Bool) -> Void)? = nil
    var didStartChangingAlpha: ((TextureLayerModel) -> Void)? = nil
    var didChangeAlpha: ((TextureLayerModel, Int) -> Void)? = nil
    var didFinishChangingAlpha: ((TextureLayerModel) -> Void)? = nil
    var didEditTitle: ((TextureLayerModel, String) -> Void)? = nil
    var didMove: ((IndexSet, Int) -> Void)? = nil

    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!)
    let range = 0 ... 255

    var body: some View {
        ZStack {
            roundedRectangleWithArrow.viewWithTopArrow(
                arrowSize: roundedRectangleWithArrow.arrowSize,
                roundedCorner: roundedRectangleWithArrow.roundedCorner
            )

            VStack {
                toolbar(textureLayers)

                TextureLayerListView(
                    canvasState: canvasState,
                    textureLayers: textureLayers,
                    didTapLayer: { layer in
                        didTapLayer?(layer)
                    },
                    didTapVisibility: { layer, isVisibility in
                        didTapVisibility?(layer, isVisibility)
                    },
                    didMove: { source, destination in
                        didMove?(source, destination)
                    }
                )

                TwoRowsSliderView(
                    title: "Alpha",
                    value: canvasState.selectedLayer?.alpha ?? 0,
                    style: sliderStyle,
                    range: range,
                    didStartChanging: {
                        guard let selectedLayer = canvasState.selectedLayer else { return }
                        didStartChangingAlpha?(selectedLayer)
                    },
                    didChange: { value in
                        guard let selectedLayer = canvasState.selectedLayer else { return }
                        didChangeAlpha?(selectedLayer, value)
                    },
                    didFinishChanging: {
                        guard let selectedLayer = canvasState.selectedLayer else { return }
                        didFinishChangingAlpha?(selectedLayer)
                    }
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(roundedRectangleWithArrow.edgeInsets)
        }
    }

}

extension TextureLayerView {

    func toolbar(
        _ textureLayers: TextureLayers
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    textureLayers.insertLayer(
                        at: textureLayers.newIndex
                    )
                },
                label: {
                    Image(systemName: "plus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    didTapRemoveButton?()
                },
                label: {
                    Image(systemName: "minus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textFieldTitle = canvasState.selectedLayer?.title ?? ""
                    isTextFieldPresented = true
                },
                label: {
                    Image(systemName: "pencil").buttonModifier(diameter: buttonSize)
                }
            )
            .hidden()
            .alert("Enter a title", isPresented: $isTextFieldPresented) {
                TextField("Enter a title", text: $textFieldTitle)
                Button("OK", action: {
                    guard let selectedLayer = canvasState.selectedLayer else { return }
                    didEditTitle?(selectedLayer, textFieldTitle)
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
        CanvasModel(
            layerIndex: 1,
            layers: [
                .init(title: "Layer0", alpha: 255),
                .init(title: "Layer1", alpha: 200),
                .init(title: "Layer2", alpha: 150),
                .init(title: "Layer3", alpha: 100),
                .init(title: "Layer4", alpha: 50),
            ]
        )
    )
    let textureLayers: TextureLayers

    init() {
        textureLayers = .init(canvasState: canvasState)
    }
    var body: some View {
        TextureLayerView(
            canvasState: canvasState,
            textureLayers: textureLayers,
            roundedRectangleWithArrow: RoundedRectangleWithArrow()
        )
        .frame(width: 256, height: 300)
    }

}
