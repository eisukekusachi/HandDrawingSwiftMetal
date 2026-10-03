//
//  Created by Eisuke Kusachi
//

import SwiftUI

struct TextureLayerToolbar: View {

    @ObservedObject private var viewModel: TextureLayerViewModel

    private let buttonThrottle = ButtonThrottle()

    private let buttonSize: CGFloat = 20

    @State private var isTextFieldPresented: Bool = false
    @State private var textFieldTitle: String = ""

    init(
        viewModel: TextureLayerViewModel
    ) {
        self.viewModel = viewModel
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(
                action: {
                    buttonThrottle.throttle(id: "insertLayer") {
                        Task { @MainActor in
                            try? await viewModel.onTapInsertButton()
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
                            try? await viewModel.onTapDeleteButton()
                        }
                    }
                },
                label: {
                    Image(systemName: "trash")
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
                    try? viewModel.onTapTitleButton(
                        selectedLayer.id,
                        title: textFieldTitle
                    )
                })
                Button("Cancel", action: {})
            }
            Spacer()

            if let onClose = viewModel.onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
                .buttonStyle(.plain)
            }
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
    private let viewModel: TextureLayerViewModel = {
        let layer = TextureLayerItem(id: LayerId(), title: "Layer0", alpha: 255, isVisible: true)
        return TextureLayerViewModel(
            textureLayers: PreviewTextureLayers(
                layers: [layer],
                selectedLayerId: layer.id
            )
        )
    }()
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
