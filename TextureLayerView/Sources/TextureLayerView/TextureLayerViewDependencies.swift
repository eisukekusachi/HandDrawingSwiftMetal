//
//  TextureLayerViewDependencies.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/11.
//

import Foundation
import MetalKit

@MainActor
final class TextureLayerViewDependencies {

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    init(device: MTLDevice) {
        do {
            textureLayersDocumentsRepository = try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                device: device
            )
        } catch {
            fatalError()
        }
    }
}

