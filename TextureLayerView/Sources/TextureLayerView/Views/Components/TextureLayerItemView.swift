//
//  TextureLayerItemView.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/05.
//

import SwiftUI

struct TextureLayerItemView: View {

    var layer: TextureLayerItem

    private let isSelected: Bool
    private let didTapRow: (TextureLayerItem) -> Void
    private let didTapVisibleButton: (TextureLayerItem) -> Void

    init(
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

    var body: some View {
        HStack {
            thumbnailView

            Text(layer.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0, alignment: .leading)
                .foregroundColor(
                    Color(
                        layer.textColor(isSelected)
                    )
                )

            Spacer()

            Text("A: \(layer.alpha)")
                .font(.caption2)
                .foregroundColor(Color(uiColor: .gray))

            Button(
                action: {
                    didTapVisibleButton(layer)
                },
                label: {
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
                }
            )
            .buttonStyle(.plain)

            Spacer()
                .frame(width: layer.padding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: layer.iconSize.height + layer.padding * 2)
        .contentShape(Rectangle())
        .onTapGesture {
            didTapRow(layer)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        let shape = RoundedRectangle(
            cornerRadius: layer.cornerRadius,
            style: .continuous
        )

        ZStack {
            shape.fill(Color.white)

            if let thumbnail = layer.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(
            width: layer.iconSize.width,
            height: layer.iconSize.height
        )
        .clipShape(shape)
        .overlay {
            shape.stroke(.gray.opacity(0.5), lineWidth: 1)
        }
        .padding(layer.padding)
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
