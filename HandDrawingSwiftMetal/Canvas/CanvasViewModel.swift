//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

class CanvasViewModel {

    /// The currently selected drawing tool, either brush or eraser.
    @Published var drawingTool: DrawingToolType = .brush

    /// Drawing with a brush
    var drawingBrush = DrawingBrush()

    /// Drawing with an eraser
    var drawingEraser = DrawingEraser()

    /// A texture that is selected
    var selectedTexture: MTLTexture? {
        return layerManager.selectedTexture
    }

    var frameSize: CGSize = .zero {
        didSet {
            drawingBrush.frameSize = frameSize
            drawingEraser.frameSize = frameSize
        }
    }

    var brushDiameter: Int {
        get { (drawingBrush.tool as? DrawingToolBrush)!.diameter }
        set { (drawingBrush.tool as? DrawingToolBrush)?.diameter = newValue }
    }
    var eraserDiameter: Int {
        get { (drawingEraser.tool as? DrawingToolEraser)!.diameter }
        set { (drawingEraser.tool as? DrawingToolEraser)?.diameter = newValue }
    }

    var brushColor: UIColor {
        get { (drawingBrush.tool as? DrawingToolBrush)!.color }
        set { (drawingBrush.tool as? DrawingToolBrush)?.setValue(color: newValue) }
    }
    var eraserAlpha: Int {
        get { (drawingEraser.tool as? DrawingToolEraser)!.alpha }
        set { (drawingEraser.tool as? DrawingToolEraser)?.setValue(alpha: newValue)}
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate
    
    var zipFileNameName: String {
        projectName + "." + CanvasViewModel.zipSuffix
    }

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    static var zipSuffix: String {
        "zip"
    }
    static var thumbnailPath: String {
        "thumbnail.png"
    }
    static var jsonFileName: String {
        "data"
    }

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

        $drawingTool
            .sink { [weak self] newValue in
                guard let self else { return }
                switch newValue {
                case .brush:
                    self.drawing = self.drawingBrush
                case .eraser:
                    self.drawing = self.drawingEraser
                }
            }
            .store(in: &cancellables)
    }

    func initAllTextures(_ textureSize: CGSize) {
        layerManager.initLayerManager(textureSize)

        drawingBrush.initTextures(textureSize)
        drawingEraser.initTextures(textureSize)
    }
}
