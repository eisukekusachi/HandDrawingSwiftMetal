//
//  TextureLayerRowView.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/05.
//

import CanvasView
import SwiftUI

public struct TextureLayerRowView: View {

    @ObservedObject var layer: TextureLayerModel

    private let isSelected: Bool
    private let didTapRow: (TextureLayerModel) -> Void
    private let didTapVisibleButton: (TextureLayerModel) -> Void

    /// The background color when the item is not selected
    private let defaultBackgroundColor: UIColor
    /// The background color when the item is selected
    private let selectedBackgroundColor: UIColor

    private let iconSize: CGSize
    private let cornerRadius: CGFloat

    private let padding: CGFloat

    public init(
        layer: TextureLayerModel,
        isSelected: Bool,
        defaultBackgroundColor: UIColor = .white,
        selectedBackgroundColor: UIColor = .black,
        iconSize: CGSize = .init(width: 32, height: 32),
        padding: CGFloat = 4,
        cornerRadius: CGFloat = 4,
        didTapRow: @escaping (TextureLayerModel) -> Void,
        didTapVisibleButton: @escaping (TextureLayerModel) -> Void
    ) {
        self.layer = layer
        self.isSelected = isSelected

        self.iconSize = iconSize
        self.padding = padding
        self.cornerRadius = cornerRadius

        self.defaultBackgroundColor = defaultBackgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor

        self.didTapRow = didTapRow
        self.didTapVisibleButton = didTapVisibleButton
    }

    public var body: some View {
        ZStack {
            Color(
                backgroundColor(isSelected)
            )

            HStack {
                if let thumbnail = layer.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .frame(width: iconSize.width, height: iconSize.height)
                        .scaledToFit()
                        .background(Color.white)
                        .padding(padding)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(.gray.opacity(0.5), lineWidth: 1.0)
                        )
                        .cornerRadius(padding)
                } else {
                    Rectangle()
                        .foregroundColor(Color.white)
                        .frame(width: iconSize.width, height: iconSize.height)
                        .padding(padding)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(.gray.opacity(0.5), lineWidth: 1.0)
                        )
                        .cornerRadius(cornerRadius)
                }

                Text(layer.title)
                    .font(.subheadline)
                    .foregroundColor(
                        Color(
                            textColor(isSelected)
                        )
                    )

                Spacer()

                Text("A: \(layer.alpha)")
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .gray))

                Image(systemName: layer.isVisible ? "eye" : "eye.slash.fill")
                    .frame(width: iconSize.width, height: iconSize.height)
                    .foregroundColor(
                        Color(
                            iconColor(isVisible: layer.isVisible, isSelected)
                        )
                    )
                    .onTapGesture {
                        didTapVisibleButton(layer)
                    }

                Spacer()
                    .frame(width: padding)
            }
        }
        .background(.clear)
        .onTapGesture {
            didTapRow(layer)
        }
    }

    private func backgroundColor(_ selected: Bool) -> UIColor {
        !selected ? defaultBackgroundColor : selectedBackgroundColor
    }
    private func textColor(_ selected: Bool) -> UIColor {
        !selected ? selectedBackgroundColor : defaultBackgroundColor
    }
    private func iconColor(isVisible: Bool, _ selected: Bool) -> UIColor {
        !selected ? selectedBackgroundColor : defaultBackgroundColor
    }
}

#Preview {
    VStack(spacing: 24) {
        TextureLayerRowView(
            layer: .init(
                id: UUID(),
                thumbnail: .init(systemName: "hand.thumbsup.fill"),
                title: "Title",
                alpha: 255,
                isVisible: true
            ),
            isSelected: false,
            didTapRow: { _ in
                print("Did tap the row")
            },
            didTapVisibleButton: { _ in
                print("Did tap the visible button")
            }
        )
        .frame(width: 256, height: 44)

        TextureLayerRowView(
            layer: .init(
                id: UUID(),
                thumbnail: .init(systemName: "hand.thumbsup.fill"),
                title: "Title",
                alpha: 255,
                isVisible: false
            ),
            isSelected: false,
            didTapRow: { _ in
                print("Did tap the row")
            },
            didTapVisibleButton: { _ in
                print("Did tap the visible button")
            }
        )
        .frame(width: 256, height: 44)

        TextureLayerRowView(
            layer: .init(
                id: UUID(),
                thumbnail: nil,
                title: "Title",
                alpha: 255,
                isVisible: true
            ),
            isSelected: false,
            didTapRow: { _ in
                print("Did tap the row")
            },
            didTapVisibleButton: { _ in
                print("Did tap the visible button")
            }
        )
        .frame(width: 256, height: 44)

        TextureLayerRowView(
            layer: .init(
                id: UUID(),
                thumbnail: .init(systemName: "hand.thumbsup.fill"),
                title: "Title",
                alpha: 255,
                isVisible: true
            ),
            isSelected: true,
            didTapRow: { _ in
                print("Did tap the row")
            },
            didTapVisibleButton: { _ in
                print("Did tap the visible button")
            }
        )
        .frame(width: 256, height: 64)

        TextureLayerRowView(
            layer: .init(
                id: UUID(),
                thumbnail: .init(systemName: "hand.thumbsup.fill"),
                title: "Title",
                alpha: 255,
                isVisible: false
            ),
            isSelected: true,
            didTapRow: { _ in
                print("Did tap the row")
            },
            didTapVisibleButton: { _ in
                print("Did tap the visible button")
            }
        )
        .frame(width: 256, height: 64)
    }
}
