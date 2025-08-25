//
//  HandDrawingContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import CanvasView
import UIKit
import Combine

final class HandDrawingContentView: UIView {

    @IBOutlet private(set) weak var canvasView: CanvasView!

    @IBOutlet private weak var resetTransformButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var loadButton: UIButton!
    @IBOutlet private weak var newButton: UIButton!

    @IBOutlet private weak var brushDiameterSlider: UISlider!
    @IBOutlet private weak var eraserDiameterSlider: UISlider!

    @IBOutlet private(set) weak var exportImageButton: UIButton!
    @IBOutlet private(set) weak var layerButton: UIButton!

    @IBOutlet weak var drawingToolButton: UIButton!

    @IBOutlet weak var brushPaletteView: UIView!
    @IBOutlet weak var eraserPaletteView: UIView!
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    let brushDrawingRenderer = BrushDrawingRenderer()
    let eraserDrawingRenderer = EraserDrawingRenderer()

    let viewModel = HandDrawingContentViewModel()

    lazy var drawingToolLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileNamedLoader<DrawingToolFile>(
                fileName: DrawingToolFile.fileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.viewModel.drawingTool.update(
                        type: .init(rawValue: file.type),
                        brushDiameter: file.brushDiameter,
                        eraserDiameter: file.eraserDiameter
                    )
                }
            },
            // Since this file is optional, if it is not found or an error occurs, simply do nothing
            ignoreError: true
         )
    }()

    lazy var brushPaletteLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileNamedLoader<BrushPaletteFile>(
                fileName: BrushPaletteFile.fileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.viewModel.brushPalette.update(
                        colors: file.hexColors.compactMap { UIColor(hex: $0) },
                        currentIndex: file.index
                    )
                }
            },
            // Since this file is optional, if it is not found or an error occurs, simply do nothing
            ignoreError: true
         )
    }()

    lazy var eraserPaletteLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileNamedLoader<EraserPaletteFile>(
                fileName: EraserPaletteFile.fileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.viewModel.eraserPalette.update(
                        alphas: file.alphas,
                        currentIndex: file.index
                    )
                }
            },
            // Since this file is optional, if it is not found or an error occurs, simply do nothing
            ignoreError: true
         )
    }()

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
        canvasView.alpha = 0.0

        subscribe()
        addEvents()

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))

        undoButton.isHidden = true
        redoButton.isHidden = true

        updateDrawingComponents(
            viewModel.drawingTool.type
        )
    }

    func setup() {
        brushDrawingRenderer.setDiameter(viewModel.drawingTool.brushDiameter)
        brushDiameterSlider.setValue(
            BrushDrawingRenderer.diameterFloatValue(viewModel.drawingTool.brushDiameter),
            animated: false
        )

        eraserDrawingRenderer.setDiameter(viewModel.drawingTool.eraserDiameter)
        eraserDiameterSlider.setValue(
            EraserDrawingRenderer.diameterFloatValue(viewModel.drawingTool.eraserDiameter),
            animated: false
        )

        updateDrawingComponents(viewModel.drawingTool.type)

        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.canvasView.alpha = 1.0
        }

        backgroundColor = .white
    }
}

private extension HandDrawingContentView {

    func subscribe() {
        viewModel.brushPalette.$currentIndex
            .sink { [weak self] index in
                guard let `self`, index < viewModel.brushPalette.colors.count else { return }
                let newColor = viewModel.brushPalette.colors[index]
                self.brushDrawingRenderer.setColor(newColor)
            }
            .store(in: &cancellables)

        viewModel.eraserPalette.$currentIndex
            .sink { [weak self] index in
                guard let `self`, index < viewModel.eraserPalette.alphas.count else { return }
                let newAlpha = viewModel.eraserPalette.alphas[index]
                self.eraserDrawingRenderer.setAlpha(newAlpha)
            }
            .store(in: &cancellables)

        viewModel.drawingTool.$brushDiameter
            .sink { [weak self] diameter in
                self?.brushDrawingRenderer.setDiameter(diameter)
            }
            .store(in: &cancellables)

        viewModel.drawingTool.$eraserDiameter
            .sink { [weak self] diameter in
                self?.eraserDrawingRenderer.setDiameter(diameter)
            }
            .store(in: &cancellables)
    }

    func changeDrawingTool() {
        viewModel.changeDrawingTool()
        updateDrawingComponents(viewModel.drawingTool.type)
    }

    func addEvents() {

        resetTransformButton.addAction(.init { [weak self] _ in
            self?.canvasView.resetTransforming()
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

        drawingToolButton.addAction(.init { [weak self] _ in
            self?.changeDrawingTool()
        }, for: .touchUpInside)

/*
        undoButton.addAction(.init { [weak self] _ in
            self?.canvasView.undo()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.canvasView.redo()
        }, for: .touchUpInside)
*/

        brushDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.viewModel.drawingTool.setBrushDiameter(slider.value)
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.viewModel.drawingTool.setEraserDiameter(slider.value)
        }, for: .valueChanged)
    }

    func updateDrawingComponents(_ tool: DrawingToolType) {
        if tool == .brush {
            drawingToolButton.setImage(.init(systemName: "pencil"), for: .normal)
            canvasView.setDrawingTool(DrawingToolType.brush.rawValue)

        } else {
            drawingToolButton.setImage(.init(systemName: "eraser"), for: .normal)
            canvasView.setDrawingTool(DrawingToolType.eraser.rawValue)
        }

        brushDiameterSlider.isHidden = tool != .brush
        brushPaletteView.isHidden = tool != .brush

        eraserDiameterSlider.isHidden = tool != .eraser
        eraserPaletteView.isHidden = tool != .eraser

        canvasView.setDrawingTool(tool.rawValue)
    }

    /*
    func setUndoRedoButtonState(_ state: UndoRedoButtonState) {
        undoButton.isEnabled = state.isUndoEnabled
        redoButton.isEnabled = state.isRedoEnabled
    }
    */
}
