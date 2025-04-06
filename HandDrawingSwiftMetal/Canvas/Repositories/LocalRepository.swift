//
//  LocalRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import MetalKit

protocol LocalRepository {

    func loadDataFromDocuments(
        sourceURL: URL,
        textureRepository: any TextureRepository
    ) -> AnyPublisher<CanvasModel, Error>

    func saveDataToDocuments(
        renderTexture: MTLTexture,
        textureLayers: TextureLayers,
        textureRepository: any TextureRepository,
        drawingTool: CanvasDrawingToolStatus,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error>

}
