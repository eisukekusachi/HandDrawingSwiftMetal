//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

class CanvasViewModel {

    let parameters = DrawingParameters()

    /// Drawing with a brush
    var drawingBrush = DrawingBrush()

    /// Drawing with an eraser
    var drawingEraser = DrawingEraser()

    var frameSize: CGSize = .zero {
        didSet {
            drawingBrush.frameSize = frameSize
            drawingEraser.frameSize = frameSize
        }
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate
    
    var zipFileNameName: String {
        projectName + "." + URL.zipSuffix
    }

    var undoObject: UndoObject {
        return UndoObject(index: layerManager.index,
                          layers: layerManager.layers)
    }

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    /// A protocol for managing drawing
    private (set) var drawing: Drawing?

    /// A protocol for managing transformations
    private (set) var transforming: Transforming!

    /// A protocol for managing file input and output
    private (set) var fileIO: FileIO!

    /// An instance for managing texture layers
    private (set) var layerManager = LayerManager()

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl(),
         transforming: Transforming = TransformingImpl()) {
        self.fileIO = fileIO
        self.transforming = transforming

        parameters.drawingToolSubject.sink { [weak self] tool in
            guard let `self` else { return }
            self.drawing = tool == .brush ? self.drawingBrush : self.drawingEraser
        }
        .store(in: &cancellables)

        parameters.setDrawingTool(.brush)
    }

    func initAllTextures(_ textureSize: CGSize) {
        layerManager.initLayerManager(textureSize)

        drawingBrush.initTextures(textureSize)
        drawingEraser.initTextures(textureSize)
    }
}
