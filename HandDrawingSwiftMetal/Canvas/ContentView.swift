//
//  ContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit
import Combine

final class ContentView: UIView {

    @IBOutlet weak var canvasView: CanvasView!
    
    @IBOutlet weak var topStackView: UIStackView!
    @IBOutlet weak var resetTransformButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var layerButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var exportImageButton: UIButton!
    @IBOutlet weak var newButton: UIButton!

    @IBOutlet weak var diameterSlider: UISlider!

    @IBOutlet weak var blackColorButton: UIButton!
    @IBOutlet weak var redColorButton: UIButton!
    @IBOutlet weak var eraserButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapResetTransformButton: (() -> Void)?
    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    var tapUndoButton: (() -> Void)?
    var tapRedoButton: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        instantiateNib()
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        instantiateNib()
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .white
        
        initUndoComponents()

        diameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
    }

}

extension ContentView {

    func applyDrawingParameters(_ drawingTool: DrawingToolModel) {
        bindInputs(drawingTool)
        bindModels(drawingTool)
    }

    private func bindInputs(_ drawingTool: DrawingToolModel) {

        resetTransformButton.addAction(.init { [weak self] _ in
            self?.tapResetTransformButton?()
        }, for: .touchUpInside)

        saveButton.addAction(.init { [weak self] _ in
            self?.tapSaveButton?()
        }, for: .touchUpInside)

        layerButton.addAction(.init { [weak self] _ in
            self?.tapLayerButton?()
        }, for: .touchUpInside)

        loadButton.addAction(.init { [weak self] _ in
            self?.tapLoadButton?()
        }, for: .touchUpInside)

        exportImageButton.addAction(.init { [weak self] _ in
            self?.tapExportImageButton?()
        }, for: .touchUpInside)

        newButton.addAction(.init { [weak self] _ in
            self?.tapNewButton?()
        }, for: .touchUpInside)

        blackColorButton.addAction(.init { _ in
            drawingTool.setDrawingTool(.brush)
            drawingTool.setBrushColor(UIColor.black.withAlphaComponent(0.75))
        }, for: .touchUpInside)

        redColorButton.addAction(.init { _ in
            drawingTool.setDrawingTool(.brush)
            drawingTool.setBrushColor(UIColor.red.withAlphaComponent(0.75))
        }, for: .touchUpInside)

        eraserButton.addAction(.init { _ in
            drawingTool.setDrawingTool(.eraser)
        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            self?.tapUndoButton?()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.tapRedoButton?()
        }, for: .touchUpInside)

        diameterSlider.addTarget(
            drawingTool,
            action:#selector(drawingTool.handleDiameterSlider),
            for: .valueChanged)

        canvasView.undoManager.refreshUndoComponentsObjectSubject
            .sink { [weak self] in
                guard let `self` else { return }
                self.refreshUndoComponents()
            }
            .store(in: &cancellables)
    }
    
    private func bindModels(_ drawingTool: DrawingToolModel) {

        drawingTool.diameterSubject
            .sink { [weak self] diameter in
                self?.diameterSlider.value = diameter
            }
            .store(in: &cancellables)

        drawingTool.backgroundColorSubject
            .sink { [weak self] color in
                self?.canvasView.backgroundColor = color
            }
            .store(in: &cancellables)

        drawingTool.matrixSubject
            .assign(to: \.matrix, on: canvasView)
            .store(in: &cancellables)

        drawingTool.textureSizeSubject
            .sink { [weak self] textureSize in
                guard let `self`, textureSize != .zero else { return }

                drawingTool.initLayers(textureSize: textureSize)
                canvasView.initRootTexture(textureSize: textureSize)

                drawingTool.commitCommandToMergeAllLayersToRootTextureSubject.send()
            }
            .store(in: &cancellables)

        drawingTool.commitCommandToMergeAllLayersToRootTextureSubject
            .sink { [weak self] in
                guard let `self` else { return }
                
                drawingTool.addCommandToMergeAllLayers(
                    onto: canvasView.rootTexture,
                    to: canvasView.commandBuffer
                )

                canvasView.commitCommandsInCommandBuffer()
            }
            .store(in: &cancellables)

        drawingTool.commitCommandsInCommandBuffer
            .sink { [weak self] in
                self?.canvasView.commitCommandsInCommandBuffer()
            }
            .store(in: &cancellables)
    }

}

extension ContentView {

    func initUndoComponents() {
        canvasView.clearUndo()
        refreshUndoComponents()
    }

    func refreshUndoComponents() {
        undoButton.isEnabled = canvasView.canUndo
        redoButton.isEnabled = canvasView.canRedo
    }

}
