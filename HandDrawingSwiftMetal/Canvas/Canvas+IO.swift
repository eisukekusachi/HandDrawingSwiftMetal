//
//  CanvasView+IO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension CanvasView {
    func load(from model: CanvasModel, projectName: String, folderURL: URL) {
        guard let viewModel else { return }

        viewModel.projectName = projectName

        if let textureName = model.textureName,
           let textureSize = model.textureSize {

            let textureUrl = folderURL.appendingPathComponent(textureName)
            let textureData: Data? = try? Data(contentsOf: textureUrl)

            if let texture = device?.makeTexture(textureSize, textureData?.encodedHexadecimals) {
                viewModel.layerManager.setTexture(texture)
            }
        }

        if let drawingTool = model.drawingTool {
            viewModel.drawingTool = .init(rawValue: drawingTool)
        }

        if let diameter = model.brushDiameter {
            self.brushDiameter = diameter
        }
        if let diameter = model.eraserDiameter {
            self.eraserDiameter = diameter
        }
        
        clearUndo()

        refreshRootTexture(commandBuffer)
        setNeedsDisplay()
    }
    
    func setTexture(textureSize: CGSize, folderUrl: URL, textureName: String) {

        let textureUrl = folderUrl.appendingPathComponent(textureName)
        let textureData: Data? = try? Data(contentsOf: textureUrl)

        if let texture = device?.makeTexture(textureSize, textureData?.encodedHexadecimals) {
            viewModel?.layerManager.setTexture(texture)
        }
    }
}
