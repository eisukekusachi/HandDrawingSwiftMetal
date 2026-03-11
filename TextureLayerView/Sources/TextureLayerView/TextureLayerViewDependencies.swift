//
//  TextureLayerViewDependencies.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/11.
//

import Foundation
import MetalKit

@MainActor
public final class TextureLayerViewDependencies {

    public let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    public init(device: MTLDevice) {
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

