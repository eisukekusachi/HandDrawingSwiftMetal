//
//  TextureLayerItemView.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/05.
//

import SwiftUI

public struct TextureLayerItemView: View {

    var layer: TextureLayerItem

    private let isSelected: Bool
    private let didTapRow: (TextureLayerItem) -> Void
    private let didTapVisibleButton: (TextureLayerItem) -> Void

    public init(
        layer: TextureLayerItem,
        isSelected: Bool,
        didTapRow: @escaping (TextureLayerItem) -> Void,
        didTapVisibleButton: @escaping (TextureLayerItem) -> Void
    ) {
        self.layer = layer
        self.isSelected = isSelected

        self.didTapRow = didTapRow
        self.didTapVisibleButton = didTapVisibleButton
    }

    public var body: some View {
        ZStack {
            Color(
                layer.backgroundColor(isSelected)
            )

            HStack {
                if let thumbnail = layer.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: layer.iconSize.width,
                            height: layer.iconSize.height
                        )
                        .background(Color.white)
                        .cornerRadius(layer.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: layer.cornerRadius)
                                .stroke(.gray.opacity(0.5), lineWidth: 1.0)
                        )
                        .padding(layer.padding)
                } else {
                    Rectangle()
                        .foregroundColor(Color.white)
                        .frame(
                            width: layer.iconSize.width,
                            height: layer.iconSize.height
                        )
                        .cornerRadius(layer.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: layer.cornerRadius)
                                .stroke(.gray.opacity(0.5), lineWidth: 1.0)
                        )
                        .padding(layer.padding)
                }

                Text(layer.title)
                    .font(.subheadline)
                    .foregroundColor(
                        Color(
                            layer.textColor(isSelected)
                        )
                    )

                Spacer()

                Text("A: \(layer.alpha)")
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .gray))

                Image(systemName: layer.isVisible ? "eye" : "eye.slash.fill")
                    .frame(
                        width: layer.iconSize.width,
                        height: layer.iconSize.height
                    )
                    .foregroundColor(
                        Color(
                            layer.iconColor(isVisible: layer.isVisible, isSelected)
                        )
                    )
                    .onTapGesture {
                        didTapVisibleButton(layer)
                    }

                Spacer()
                    .frame(width: layer.padding)
            }
        }
        .frame(height: layer.iconSize.height + layer.padding * 2)
        .background(.clear)
        .onTapGesture {
            didTapRow(layer)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        TextureLayerItemView(
            layer: .init(
                id: LayerId(),
                title: "Title",
                alpha: 255,
                isVisible: true,
                thumbnail: nil
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

        TextureLayerItemView(
            layer: .init(
                id: LayerId(),
                title: "Title",
                alpha: 255,
                isVisible: false,
                thumbnail: nil
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

        TextureLayerItemView(
            layer: .init(
                id: LayerId(),
                title: "Title",
                alpha: 255,
                isVisible: true,
                thumbnail: nil
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

        TextureLayerItemView(
            layer: .init(
                id: LayerId(),
                title: "Title",
                alpha: 255,
                isVisible: true,
                thumbnail: nil
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

        TextureLayerItemView(
            layer: .init(
                id: LayerId(),
                title: "Title",
                alpha: 255,
                isVisible: false,
                thumbnail: nil
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
