//
//  LocalRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import MetalKit
import Combine

protocol LocalRepository {

    func loadDataFromDocuments(
        sourceURL: URL
    ) -> AnyPublisher<CanvasModel, Error>

    func saveDataToDocuments(
        renderTexture: MTLTexture,
        layerManager: TextureLayers,
        drawingTool: DrawingToolModel,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error>

}
