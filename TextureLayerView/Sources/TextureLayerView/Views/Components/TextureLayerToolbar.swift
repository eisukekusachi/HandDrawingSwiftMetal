//
//  TextureLayerToolbar.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import SwiftUI

public struct TextureLayerToolbar: View {

    @ObservedObject private var viewModel: TextureLayerViewModel

    private let buttonThrottle = ButtonThrottle()

    private let buttonSize: CGFloat = 20

    private let device: MTLDevice?

    @State private var isTextFieldPresented: Bool = false
    @State private var textFieldTitle: String = ""

    init(
        device: MTLDevice? = nil,
        viewModel: TextureLayerViewModel
    ) {
        self.device = device
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 16) {
            Button(
                action: {
                    buttonThrottle.throttle(id: "insertLayer") {
                        Task { @MainActor in
                            do {
                                try await viewModel.onTapInsertButton(device: device)
                            } catch {
                                Logger.error(error)
                            }
                        }
                    }
                },
                label: {
                    Image(systemName: "plus.circle")
                        .buttonModifier(diameter: buttonSize)
                }
            )

            Button(
                action: {
                    buttonThrottle.throttle(id: "removeLayer") {
                        Task { @MainActor in
                            do {
                                try await viewModel.onTapDeleteButton()
                            } catch {
                                Logger.error(error)
                            }
                        }
                    }
                },
                label: {
                    Image(systemName: "minus.circle")
                        .buttonModifier(diameter: buttonSize)
                }
            )

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
                    viewModel.onTapTitleButton(
                        selectedLayer.id,
                        title: textFieldTitle
                    )
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
    private let viewModel = TextureLayerViewModel()

    private let textureLayers = TextureLayersState()

    private let data: TextureLayersModel = .init(
        layers: [
            .init(
                id: LayerId(),
                title: "Layer0",
                alpha: 255,
                isVisible: true
            )
        ],
        layerIndex: 0,
        textureSize: .zero
    )

    var body: some View {
        TextureLayerToolbar(
            viewModel: viewModel
        )
        .frame(width: 320, height: 300)
        .onAppear {
            Task {
                textureLayers.update(data)
                viewModel.update(textureLayers)
            }
        }
    }
}

#Preview {
    PreviewView()
}
