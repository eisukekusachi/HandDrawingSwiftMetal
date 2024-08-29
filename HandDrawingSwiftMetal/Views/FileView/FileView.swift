//
//  FileView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import SwiftUI

struct FileView: View {

    var zipFileList: [String] = []
    var didTapItem: ((String) -> Void)?

    var body: some View {
        ForEach(0 ..< zipFileList.count, id: \.self) { index in
            Text(zipFileList[index])
                .onTapGesture {
                    didTapItem?(zipFileList[index])
                }
        }
    }
}

#Preview {
    FileView(zipFileList: ["test1.zip",
                           "test2.zip"])
}
