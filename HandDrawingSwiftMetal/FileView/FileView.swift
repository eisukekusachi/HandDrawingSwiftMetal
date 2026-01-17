//
//  FileView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import SwiftUI

struct FileView: View {

    private let targetURL: URL
    private let zipFileList: [String]
    private let onTapItem: ((URL) -> Void)

    init(
        targetURL: URL,
        suffix: String,
        onTapItem: @escaping ((URL) -> Void)
    ) {
        self.targetURL = targetURL
        self.zipFileList = targetURL.allFileURLs(suffix: suffix).map {
            $0.lastPathComponent
        }
        self.onTapItem = onTapItem
    }

    var body: some View {
        ForEach(0 ..< zipFileList.count, id: \.self) { index in
            Text(zipFileList[index])
                .onTapGesture {
                    onTapItem(
                        targetURL.appendingPathComponent(zipFileList[index])
                    )
                }
        }
    }
}

#Preview {
    FileView(
        targetURL: URL(fileURLWithPath: NSHomeDirectory() + "/Documents"),
        suffix: "zip",
        onTapItem: { _ in }
    )
}
