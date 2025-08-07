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

    public init(
        layer: TextureLayerModel,
        isSelected: Bool,
        didTapRow: @escaping (TextureLayerModel) -> Void,
        didTapVisibleButton: @escaping (TextureLayerModel) -> Void
    ) {
        self.layer = layer
        self.isSelected = isSelected
        self.didTapRow = didTapRow
        self.didTapVisibleButton = didTapVisibleButton
    }

    public var body: some View {
        ZStack {
            Color(
                backgroundColor(isSelected)
            )

            HStack {
                Spacer()
                    .frame(width: 8)

                if let thumbnail = layer.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .scaledToFit()
                        .background(Color.white)
                        .cornerRadius(4)
                        .overlay(
                            Rectangle()
                                .stroke(.gray.opacity(0.5), lineWidth: 1.0)
                        )
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
                    .frame(width: 32, height: 32)
                    .foregroundColor(
                        Color(
                            iconColor(layer: layer, isSelected)
                        )
                    )
                    .onTapGesture {
                        didTapVisibleButton(layer)
                    }

                Spacer()
                    .frame(width: 8)
            }
        }
        .onTapGesture {
            didTapRow(layer)
        }
    }

    private func backgroundColor(_ selected: Bool) -> UIColor {
        if selected {
            return UIColor(named: "component") ?? .clear
        } else {
            return UIColor(named: "reversalComponent") ?? .clear
        }
    }
    private func textColor(_ selected: Bool) -> UIColor {
        if selected {
            return UIColor(named: "reversalComponent") ?? .clear
        } else {
            return UIColor(named: "component") ?? .clear
        }
    }
    private func iconColor(layer: TextureLayerModel, _ selected: Bool) -> UIColor {
        if selected {
            return layer.isVisible ? .white : .lightGray
        } else {
            return layer.isVisible ? .black : .darkGray
        }
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
            isSelected: true,
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
            isSelected: false,
            didTapRow: { _ in
                print("Did tap the row")
            },
            didTapVisibleButton: { _ in
                print("Did tap the visible button")
            }
        )
        .frame(width: 256, height: 44)
    }
}
