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

    var frameSize: CGSize = .zero {
        didSet {
            parameters.frameSize = frameSize
        }
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var zipFileNameName: String {
        projectName + "." + URL.zipSuffix
    }

    var undoObject: UndoObject {
        return UndoObject(index: parameters.layerManager.index,
                          layers: parameters.layerManager.layers)
    }

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    /// A protocol for managing transformations
    private let transforming = Transforming()

    /// A protocol for managing file input and output
    private (set) var fileIO: FileIO!

    private var displayLink: CADisplayLink?

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl()) {
        self.fileIO = fileIO

        parameters.pauseDisplayLinkSubject
            .sink { [weak self] pause in
                self?.pauseDisplayLinkLoop(pause)
            }
            .store(in: &cancellables)

        parameters.setDrawingTool(.brush)

        // Configure the display link for rendering.
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    func initTexture(canvasRootTexture: MTLTexture) {
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer() else { return }

        let textureSize = parameters.textureSizeSubject.value

        parameters.layerManager.reset(textureSize)

        parameters.mergeAllLayers(to: canvasRootTexture, commandBuffer)
        commandBuffer.commit()

        parameters.setNeedsDisplaySubject.send()
    }

}

extension CanvasViewModel {

    func didTapResetTransformButton() {
        resetMatrix()
        parameters.setNeedsDisplaySubject.send()
    }

    func newCanvas(rootTexture: MTLTexture) {
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer()
        else { return }

        projectName = Calendar.currentDate

        parameters.clearUndoSubject.send()

        resetMatrix()

        let textureSize = parameters.textureSizeSubject.value
        parameters.layerManager.reset(textureSize)
        parameters.layerManager.updateNonSelectedTextures(commandBuffer: commandBuffer)
        parameters.mergeAllLayers(to: rootTexture, commandBuffer)

        commandBuffer.commit()

        parameters.setNeedsDisplaySubject.send(())
    }

}

extension CanvasViewModel {

    func resetMatrix() {
        transforming.setStoredMatrix(.identity)
        parameters.matrixSubject.send(.identity)
    }

}

extension CanvasViewModel {

    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        parameters.setNeedsDisplaySubject.send()
    }

    /// Start or stop the display link loop based on the 'play' parameter.
    private func pauseDisplayLinkLoop(_ pause: Bool) {
        if pause {
            if displayLink?.isPaused == false {
                // Pause the display link after updating the display.
                parameters.setNeedsDisplaySubject.send()
                displayLink?.isPaused = true
            }

        } else {
            if displayLink?.isPaused == true {
                displayLink?.isPaused = false
            }
        }
    }

}

extension CanvasViewModel {

    func getMatrix(transformationData: TransformationData, touchPhase: UITouch.Phase) -> CGAffineTransform? {
        transforming.getMatrix(transformationData: transformationData,
                               frameCenterPoint: Calc.getCenter(frameSize),
                               touchPhase: touchPhase)
    }

    func setMatrix(_ matrix: CGAffineTransform) {
        transforming.setStoredMatrix(matrix)
    }

}
