//
//  HandDrawingViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/04.
//

import Core
import Foundation
import TextureLayerView

@MainActor
final class HandDrawingViewDependencies {

    let fileManager: FileManaging
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    init(
        fileManager: FileManaging? = nil,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.fileManager = fileManager ?? FileManagerWrapper()
        self.textureLayersDocumentsRepository =
            textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
