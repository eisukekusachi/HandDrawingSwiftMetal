//
//  FileView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import CanvasView
import SwiftUI

struct FileView: View {

    private let list: [LocalFileItem]
    private let onTapItem: ((URL) -> Void)

    init(
        list: [LocalFileItem],
        onTapItem: @escaping ((URL) -> Void)
    ) {
        self.list = list
        self.onTapItem = onTapItem
    }

    var body: some View {
        ScrollView {
            ForEach(0 ..< list.count, id: \.self) { index in
                itemView(item: list[index])
                    .onTapGesture {
                        onTapItem(
                            list[index].fileURL
                        )
                    }
            }
        }
        .padding(.vertical, 24)
    }

    private func itemView(item: LocalFileItem) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.92, green: 0.92, blue: 0.92))

            if let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .opacity(0.5)
                    Spacer()
                }
            }

            Text(item.title)
                .bold()
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white.opacity(0.75))
        }
        .frame(width: 300, height: 300)
        .cornerRadius(12)
        .padding(.vertical, 4)
    }
}

#Preview {
    FileView(
        list: [
            .init(
                title: "Test",
                createdAt: Date(),
                updatedAt: Date(),
                image: nil,
                fileURL: URL(fileURLWithPath: "")
            ),
            .init(
                title: "Test Test Test Test Test Test Test Test Test Test Test Test",
                createdAt: Date(),
                updatedAt: Date(),
                image: nil,
                fileURL: URL(fileURLWithPath: "")
            )
        ],
        onTapItem: { _ in }
    )
}
