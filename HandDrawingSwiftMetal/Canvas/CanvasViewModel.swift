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

    private var displayLink: CADisplayLink?

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

        parameters.runDisplayLinkSubject
            .sink { [weak self] run in
                self?.runDisplayLinkLoop(run)
            }
            .store(in: &cancellables)

        parameters.setDrawingTool(.brush)

        // Configure the display link for rendering.
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    func initAllTextures(_ textureSize: CGSize) {
        layerManager.initLayerManager(textureSize)

        drawingBrush.initTextures(textureSize)
        drawingEraser.initTextures(textureSize)
    }

}

extension CanvasViewModel {

    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        parameters.setNeedsDisplaySubject.send()
    }

    /// Start or stop the display link loop based on the 'play' parameter.
    private func runDisplayLinkLoop(_ play: Bool) {
        if play {
            if displayLink?.isPaused == true {
                displayLink?.isPaused = false
            }
        } else {
            if displayLink?.isPaused == false {
                // Pause the display link after updating the display.
                parameters.setNeedsDisplaySubject.send()
                displayLink?.isPaused = true
            }
        }
    }

}

