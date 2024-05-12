//
//  LayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerView: View {

    @ObservedObject var layerManager: LayerManager
    @ObservedObject var layerViewPresentation: LayerViewPresentation

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    var didTapLayer: (LayerEntity) -> Void
    var didTapAddButton: () -> Void
    var didTapRemoveButton: () -> Void
    var didTapVisibility: (LayerEntity, Bool) -> Void
    var didChangeAlpha: (LayerEntity, Int) -> Void
    var didEditTitle: (LayerEntity, String) -> Void
    var didMove: (LayerEntity, IndexSet, Int) -> Void

    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!)
    let range = 0 ... 255

    var body: some View {
        ZStack {
            layerViewPresentation.viewWithTopArrow(
                arrowSize: layerViewPresentation.arrowSize,
                roundedCorner: layerViewPresentation.roundedCorner
            )

            VStack {
                toolbar(
                    layerManager: layerManager,
                    didTapAddButton: didTapAddButton,
                    didTapRemoveButton: didTapRemoveButton,
                    didEditTitle: didEditTitle
                )

                LayerListView(
                    layerManager: layerManager,
                    didTapLayer: { layer in
                        didTapLayer(layer)
                    },
                    didTapVisibility: { layer, isVisibility in
                        didTapVisibility(layer, isVisibility)
                    },
                    didMove: { layer, source, destination in
                        didMove(layer, source, destination)
                    }
                )

                TwoRowsSliderView(
                    title: "Alpha",
                    value: layerManager.selectedLayerAlpha,
                    style: sliderStyle,
                    range: range,
                    didChange: { value in
                        guard let selectedLayer = layerManager.selectedLayer else { return }
                        didChangeAlpha(selectedLayer, value)
                    }
                )
                .padding(.top, 4)
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(layerViewPresentation.edgeInsets)
        }
    }

}

extension LayerView {

    func toolbar(
        layerManager: LayerManager,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didEditTitle: @escaping (LayerEntity, String) -> Void
    ) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(
                action: {
                    didTapAddButton()
                },
                label: {
                    Image(systemName: "plus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    didTapRemoveButton()
                },
                label: {
                    Image(systemName: "minus.circle").buttonModifier(diameter: buttonSize)
                }
            )

            Spacer().frame(width: 16)

            Button(
                action: {
                    textFieldTitle = layerManager.selectedLayer?.title ?? ""
                    isTextFieldPresented = true
                },
                label: {
                    Image(systemName: "pencil").buttonModifier(diameter: buttonSize)
                }
            )
            .alert("Enter a title", isPresented: $isTextFieldPresented) {
                TextField("Enter a title", text: $textFieldTitle)
                Button("OK", action: {
                    guard let selectedLayer = layerManager.selectedLayer else { return }
                    layerManager.updateTitle(selectedLayer,
                                             $textFieldTitle.wrappedValue)
                })
                Button("Cancel", action: {})
            }
            Spacer()
        }
        .padding(8)
    }

    func selectedTextureAlphaSlider(layerManager: LayerManager) -> some View {
        TwoRowsSliderView(
            title: "Alpha",
            value: layerManager.selectedLayerAlpha,
            style: sliderStyle,
            range: range) { value in
                guard let selectedLayer = layerManager.selectedLayer else { return }
                layerManager.update(selectedLayer, alpha: value)
                layerManager.refreshCanvasWithMergingDrawingLayers()
            }
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
    }

}

#Preview {

    LayerView(
        layerManager: LayerManager(),
        layerViewPresentation: LayerViewPresentation(),
        didTapLayer: { layer in
            print("Tap layer")
        },
        didTapAddButton: {
            print("Add")
        },
        didTapRemoveButton: {
            print("Remove")
        },
        didTapVisibility: { layer, value in
            print("Change visibility")
        },
        didChangeAlpha: { layer, value in
            print("Change alpha")
        },
        didEditTitle: { layer, value in
            print("Change title")
        },
        didMove: { layer, source, destination in
            print("Moved")
        }
    )

}
