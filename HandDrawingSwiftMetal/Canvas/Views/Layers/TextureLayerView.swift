//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerView<T: TextureLayerProtocol>: View {

    @ObservedObject var layerManager: LayerManager<T>
    @ObservedObject var roundedRectangleWithArrow: RoundedRectangleWithArrow

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    var didTapLayer: (T) -> Void
    var didTapAddButton: () -> Void
    var didTapRemoveButton: () -> Void
    var didTapVisibility: (T, Bool) -> Void
    var didChangeAlpha: (T, Int) -> Void
    var didEditTitle: (T, String) -> Void
    var didMove: (T, IndexSet, Int) -> Void

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
                toolbar(
                    layerManager: layerManager,
                    didTapAddButton: didTapAddButton,
                    didTapRemoveButton: didTapRemoveButton,
                    didEditTitle: didEditTitle
                )

                ImageLayerListView<T>(
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
                    value: layerManager.selectedLayer?.alpha ?? 0,
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
            .padding(roundedRectangleWithArrow.edgeInsets)
        }
    }

}

extension TextureLayerView {

    func toolbar(
        layerManager: LayerManager<T>,
        didTapAddButton: @escaping () -> Void,
        didTapRemoveButton: @escaping () -> Void,
        didEditTitle: @escaping (T, String) -> Void
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
                    didEditTitle(selectedLayer, textFieldTitle)
                })
                Button("Cancel", action: {})
            }
            Spacer()
        }
        .padding(8)
    }

}

#Preview {

    TextureLayerView(
        layerManager: TextureLayerManager(),
        roundedRectangleWithArrow: RoundedRectangleWithArrow(),
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
