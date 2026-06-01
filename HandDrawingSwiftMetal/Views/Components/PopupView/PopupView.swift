//
//  PopupView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/30.
//

import SwiftUI

struct PopupView<Content: View>: View {

    @ObservedObject private var viewModel: PopupViewModel

    private let content: () -> Content

    private let cornerRadius: CGFloat
    private let contentPadding: EdgeInsets
    private let backgroundColor: Color
    private let borderColor: Color
    private let borderWidth: CGFloat

    init(
        _ viewModel: PopupViewModel,
        cornerRadius: CGFloat = 26,
        contentPadding: EdgeInsets = .init(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        ),
        backgroundColor: Color = .init(uiColor: .viewBackground),
        borderColor: Color = .primary.opacity(0.12),
        borderWidth: CGFloat = 1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.viewModel = viewModel
        self.cornerRadius = cornerRadius
        self.contentPadding = contentPadding
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.content = content
    }

    var body: some View {
        if !viewModel.isHidden {
            GeometryReader { proxy in
                let targetFrame = viewModel.targetFrame
                let popupRect = viewModel.popupRect(
                    containerWidth: proxy.size.width
                )

                content()
                    .padding(contentPadding)
                    .frame(
                        width: popupRect.width,
                        height: popupRect.height,
                        alignment: .topLeading
                    )
                    .background(backgroundColor, in: cardShape)
                    .overlay {
                        cardShape.strokeBorder(
                            borderColor,
                            lineWidth: borderWidth
                        )
                    }
                    .clipShape(cardShape)
                    .offset(
                        x: popupRect.minX,
                        y: popupRect.minY
                    )
                    .allowsHitTesting(viewModel.isUserInteractionEnabled)
            }
        }
    }

    private var cardShape: RoundedRectangle {
        .init(cornerRadius: cornerRadius, style: .continuous)
    }
}

#Preview("Top Leading") {
    PopupPreview(alignment: .topLeading)
}

#Preview("Top Trailing") {
    PopupPreview(alignment: .topTrailing)
}

#Preview("Bottom Leading") {
    PopupPreview(alignment: .bottomLeading)
}

#Preview("Bottom Trailing") {
    PopupPreview(alignment: .bottomTrailing)
}

private struct PopupPreview: View {

    let alignment: Alignment

    @StateObject private var viewModel = PopupViewModel(
        size: .init(width: 300, height: 200),
        placement: .top,
        isHidden: false
    )

    private struct ButtonAnchorKey: PreferenceKey {
        static var defaultValue: Anchor<CGRect>?
        static func reduce(
            value: inout Anchor<CGRect>?,
            nextValue: () -> Anchor<CGRect>?
        ) {
            value = nextValue() ?? value
        }
    }

    var body: some View {
        ZStack(alignment: alignment) {
            Color.white
                .ignoresSafeArea()

            Button(
                action: { viewModel.toggleView() },
                label: { Text(String("Button")) }
            )
            .padding()
            .anchorPreference(
                key: ButtonAnchorKey.self,
                value: .bounds,
                transform: { $0 }
            )
        }
        .overlayPreferenceValue(ButtonAnchorKey.self) { anchor in
            GeometryReader { proxy in
                let buttonRect = anchor.map { proxy[$0] } ?? .zero

                PopupView(viewModel) {
                    VStack(spacing: 0) {
                        Text(String("Popup Content"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onAppear {
                    viewModel.targetFrame = buttonRect
                    viewModel.isHidden = false
                }
                .onChange(of: buttonRect) { newValue in
                    viewModel.targetFrame = newValue
                }
            }
        }
    }
}
